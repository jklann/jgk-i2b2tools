
library(tidyverse)
library(lubridate)
library(grid)
library(glue)
library(directlabels)

#This part calculates stuff. If you've loaded chart_raw, calculate the number of patients with chart-reviewed COVID-admission or chart-reviewed non-COVID-admission

round_any <- function(x, accuracy, f = round) {
  f(x / accuracy) * accuracy
}

# Blurring function from Trang. Thanks Trang!
blur_it <- function(df, vars, blur_abs, mask_thres) {
  # Obfuscate count values.
  # If blurring range is +/-3, or blur_abs = 3,
  # the count receive a small addition of a random number from -3 to 3.
  # If a count is less than mask_thres, set that count to 0.

  for (var in vars) {
    var <- sym(var)
    blur_vec <- sample(seq(-blur_abs, blur_abs), nrow(df), replace = TRUE)
    df <- df %>%
      mutate(
        !!var := !!var + blur_vec,
        !!var := ifelse(abs(!!var) < mask_thres, 0, !!var)
      )
  }
  df
}

# Simple blurring function for a single value. Does the same thing as blur_it.
blur_that <- function(value, blur_abs, mask_thres) {
  as.integer(ifelse(value < mask_thres, 0, value + sample(seq(-blur_abs, blur_abs), 1)))
}

# Thanks Chuan Hong for this summary stats function!
# Sensitivity: TP/(All Positive)
# Variable names: first bit is test pos/neg, second bit is truth pos/neg
PAR.fun <- function(n11, n10, n01, n00) {
  sens <- n11 / (n11 + n01)
  spec <- n00 / (n10 + n00)
  ppv <- n11 / (n10 + n11)
  npv <- n00 / (n00 + n01)
  fscore <- 2 * sens * ppv / (sens + ppv)
  res <- c(c(sens, spec, ppv, npv, fscore, n11, n10, n01, n00))
  names(res) <- c("sens", "spec", "ppv", "npv", "fscore", "TP", "FP", "FN", "TN")
  res
}

# Compute total days in hospital by patient
# 2.2 version - UNCOMMENT FOR 2.2
days_hosp <- clin_raw %>% filter(in_hospital==1) %>% group_by(patient_num) %>% summarise(cohort=cohort,days_in_hospital=max(days_since_admission),.groups='drop') %>% distinct()
#days_hosp <- clin_raw %>% filter(in_hospital==1) %>% group_by(patient_num) %>% summarise(days_in_hospital=max(days_since_admission),.groups='drop') %>% distinct()

# Select patients that fit the filter
# jgk 10/5/21 - user selected # of days in hospital, but limited to max days patient was in hospital
pt_level_df <- obs_raw %>% inner_join(days_hosp,by="patient_num") %>%
  mutate(selected = concept_code %in% fource_filter & 
           between(days_since_admission, -1, max_days_in_hospital) & days_since_admission<days_in_hospital) %>% 
  group_by(patient_num) %>%
  mutate(label = if_else(max(selected) == 1, "selected", "diff")) %>%
  left_join(chart_raw, by = "patient_num") %>%
  inner_join(select(demo_raw, patient_num, admission_date), by = "patient_num") 

# jgk - for computing AND filter

# number of elements in filter by patient
set_size_df <- pt_level_df %>% group_by(patient_num) %>% filter(concept_code %in% fource_filter & 
           between(days_since_admission, -1, max_days_in_hospital)) %>% select(patient_num,concept_code) %>% distinct_all() %>%
          arrange(patient_num,concept_code) %>% summarise(set_size=n_distinct(concept_code),.groups="drop")

# Set label to "and" if entire filter is extant for pt, if fource_filter_AND is set
if(fource_filter_AND==TRUE) {
  if (is.na(andsize)) { andsize = length(fource_filter) }
  pt_level_df$label="diff"  
  pt_level_df <- pt_level_df %>% left_join(set_size_df,by="patient_num") %>%  mutate(set_size=ifelse(is.na(set_size),0,set_size)) %>%
    mutate(label=if_else(set_size >= andsize & set_size<=length(fource_filter),'selected','diff'))
}

# jgk - shrink the set size to one row per pt - used for computing % hospitalizations removed by filter
pt_level_onerow_df <- pt_level_df %>% group_by(patient_num) %>% arrange(days_since_admission) %>% filter(row_number()==1) %>% filter(admitted_for_covid<2) 

pre_pts_byweek <- pt_level_df %>%
  select(label, patient_num, admission_date, admitted_for_covid) %>%
  distinct() %>%
  mutate(week = week(admission_date) + ((year(admission_date) - 2020) * 52)) %>%
  group_by(week, label) %>%
  summarise(
    truedot = sum(subset(admitted_for_covid,admitted_for_covid<2), na.rm = TRUE), #jgk 9-2-21, handle maybes coded as 2
    falsedot = sum(!subset(admitted_for_covid,admitted_for_covid<2), na.rm = TRUE),
    n_week = n() %>% na_if(0), .groups = "drop"
  )

# Truedot = chart reviewed as admitted for covid
# Falsedot = chart reviewed as not admitted for COVID
# n_week = total # in this category (all, kept by filter, removed by filter)
pts_byweek <- pre_pts_byweek %>%
  group_by(week) %>%
  summarise(n_week = sum(n_week, na.rm = TRUE), .groups = "drop") %>%
  mutate(label = "all", truedot = 0, falsedot = 0) %>%
  bind_rows(pre_pts_byweek) %>%
  mutate(
    label = label %>% fct_recode(
      "All patients" = "all",
      "Kept patients" = "selected",
      "Removed patients" = "diff"
    ),
    week_name = ymd("2020-01-01") + weeks(week)
  )

blurred_pts_byweek <- pts_byweek %>%
  # Blur truedot/falsedota by just rounding up to bins the size of the threshold
  mutate(
    truedot = round_any(truedot, threshold) + 1,
    falsedot = round_any(falsedot, threshold) + 1
  ) %>%
  blur_it("n_week", blur, threshold)

# This tells us summary stats on how many admissions are being removed and how well it performs compared to chart review. The percentage graph below shows this by week.

# 2x2 table
n1 <- pts_byweek %>%
  group_by(label) %>%
  summarise(sum_true = sum(truedot), sum_false = sum(falsedot))
summary_stats <- unlist(PAR.fun(n1[3, 2], n1[3, 3], n1[2, 3], n1[2, 2]))

# Proportion of patients with special labs vs. all pts
pct_alltime <- mean(pt_level_onerow_df$label=="selected") * 100
print(glue("Some stats on filter: {paste(fource_filter, collapse = ',')}"))
print(glue("Days in hospital / AND filter: {paste(max_days_in_hospital,'/',fource_filter_AND)}"))
print(glue("Percent of admissions selected (kept) by the filter: {round(pct_alltime,2)}%"))
print(summary_stats, digits = 3)

# Build some data frames for plotting
# JGK - using blurred version
rug_df <- pts_byweek %>%
  pivot_longer(cols = c(truedot, falsedot)) %>%
  filter(!is.na(value)) %>%
  select(week_name, label, name, value) %>%
  uncount(weights = value) %>%
  mutate(name = name %>% fct_recode(
    "Correct" = "truedot",
    "Incorrect" = "falsedot"
  ))

# JGK - using blurred version
point_df <- pts_byweek %>%
  pivot_longer(cols = c(truedot, falsedot)) %>%
  filter(!is.na(value)) %>%
  mutate(name = name %>% fct_recode(
    "Correct" = "truedot",
    "Incorrect" = "falsedot"
  ))

annotate_df <- tibble(
  label = names(summary_stats[1:2]) %>%
    recode(
      "sens" = "Sensitivity",
      "spec" = "Specificity"
    ),
  summary_stats = summary_stats[1:2],
  x = as.Date(c("2021-02-28", "2021-02-28")),
  y = c(275, 250)
) %>%
  mutate(label = glue::glue("{label}: {round(summary_stats, 2)}"))

# # Visualize
# # Reference I used for point shapes: http://www.sthda.com/english/wiki/ggplot2-point-shapes
# # And colors: http://sape.inf.usi.ch/quick-reference/ggplot2/colour
# And linetypes: http://sape.inf.usi.ch/quick-reference/ggplot2/linetype

plot_trend <- function(df, cap = "") {
  fltext <- case_when((fource_filter_AND==TRUE & andsize < length(fource_filter)) ~ glue("ANY {andsize} of {paste(fource_filter, collapse = ',')}"),
                      (fource_filter_AND==TRUE & andsize == length(fource_filter)) ~ glue("ALL of {paste(fource_filter, collapse = ',')}"),
                      (fource_filter_AND==FALSE) ~ glue("ANY of {paste(fource_filter, collapse = ',')}"))                                                  
  df %>%
    ggplot(aes(y = n_week, x = week_name)) +
    geom_line(aes(alpha = label, linetype = label)) +
    theme_classic() +
    scale_linetype_manual(values = c("solid","dotted","longdash")) +
    #scale_color_manual(values=c("grey44","black","black")) + 
    scale_alpha_discrete(range = c(1, 0.75,0.5)) +
    scale_color_brewer(palette = "Dark2", direction = -1) +
    guides(linetype = FALSE, alpha = FALSE) +
    scale_x_date(expand = expansion(c(0, 0), c(10, 90))) +
    #ggtitle(paste("Patients removed by With-COVID detection filter\n ")) +
    labs(
      color = NULL, size = "Chart reviewed",
      y = "Number of admissions by week", x = NULL,
      caption = glue("Site: {currSiteId}
                     Filter rule: {fltext}
                     {cap}")
    ) +
    directlabels::geom_dl(aes(label = label),
                          method = list(directlabels::dl.trans(x = x + .2), method=list("top.points",hjust=0.5,cex=0.75))#"top.bumpup")#"last.bumpup")
    ) +
    theme(legend.position = "bottom") +
    geom_text(data = annotate_df, aes(x = x + 100, y = y + 100, label = label))
}

plot_rug <- function(df, cap = "") {
  df %>%
    plot_trend(cap) +
    geom_rug(
      data = rug_df,
      aes(x = week_name, y = NA_real_, color = name, linetype = label),
      position = "jitter"
    )
}

plot_donut <- function(df, cap = "") {
  df %>%
    plot_trend(cap) +
    geom_point(
      data = point_df %>% filter(value > 0),
      aes(y = n_week, x = week_name, size = value, color = name),
      alpha = 0.8, shape = 21, stroke = 2
    ) 
}

# Save Results and save the blurred version to /4ceData/out/[siteid]_admitfilterresults.rda
# TODO : We don't save the counts in the summary stats because they're not blurred. We could blur them!
results <- list(
  pts_byweek = blurred_pts_byweek,
  annotate_df = annotate_df,
  rug_df= rug_df,
  point_df = point_df,
  # pts_pct_byweek = pct_pts,
  summary_stats = summary_stats[1:5],
  pct_alltime = pct_alltime,
  currSiteId = currSiteId,
  fource_filter = fource_filter,
  fource_filter_AND = fource_filter_AND,
  fource_filter_AND_size = andsize,
  rulename = rulename
)
site_results <- paste0(currSiteId,"_",rulename,"_results")
assign(site_results, results)
save(list = site_results, file = file.path(out_dir, paste0(currSiteId,"_",rulename,"_filtergraph.rda")))

#plot_donut(pts_byweek)
#plot_rug(pts_byweek)
#plot_donut(blurred_pts_byweek, "Obfuscated")
#plot_rug(blurred_pts_byweek, "Obfuscated")
