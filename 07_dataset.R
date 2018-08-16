library(tidyverse)

authors_df_unfltd = read_rds('03_authors.rds') %>%
    filter(!duplicated(.))
names_df = read_csv('04_names_verif.csv', na = 'Ignored') %>%
    filter(!duplicated(.))

phil_sci = read_rds('06_phil_sci.Rds')

gender_df = read_rds('06_gender.Rds')

## Combine author-level metadata, canonical names, and gender attribution
authors_df = authors_df_unfltd %>%
    left_join(names_df, 
              by = c('family' = 'Orig Family', 
                     'given' = 'Orig Given')) %>% 
    rename(family_orig = family, 
           given_orig = given) %>% 
    ## Springer had some encoding errors that caused problems w/ deduping
    mutate(family = ifelse(!is.na(`Canonical Family`), 
                           `Canonical Family`, 
                           family_orig), 
           given = ifelse(!is.na(`Canonical Given`), 
                          `Canonical Given`, 
                          given_orig)) %>%
    ## Filter down to philosophers of science
    inner_join(phil_sci) %>%
    ## Join gender attribution
    left_join(gender_df)

## Output ----
write_rds(authors_df, '07_dataset.Rds')
authors_df %>%
    select_if(negate(is.list)) %>%
    write_csv('07_dataset.csv')




## Descriptive stats and plots ----
## Count of authors
authors_df %>%
    count(given, family) %>%
    nrow()

## Counts of authors, by gender
authors_df %>%
    count(given, family, gender_attr) %>%
    count(gender_attr) %>%
    mutate(frac = nn / sum(nn))

## Count of phil sci papers
authors_df %>%
    count(doi, title) %>%
    nrow()


theme_set(theme_bw() + theme(legend.position = 'bottom'))
color_gender = scale_color_manual(name = 'Gender',
                                  labels = c('Women', 
                                             'Indeterminate', 
                                             'Men'), 
                                  values = c('red', 'grey', 
                                             'blue'))
fill_gender = scale_fill_manual(name = 'Gender',
                                labels = c('Women', 
                                           'Indeterminate', 
                                           'Men'), 
                                values = c('red', 'grey', 'blue'))

## Total paper x author combinations per year, by gender
ggplot(authors_df, aes(pub_year, color = gender_attr)) + 
    geom_freqpoly(binwidth = 1) +
    color_gender +
    labs(x = 'Year', y = 'Paper count') +
    scale_x_continuous(limits = c(NA, 2017))
ggsave('07_papers_per_year.png', width = 6, height = 6*3/5)

## Total authors per year, by gender
authors_df %>%
    count(pub_year, family, given, gender_attr) %>% 
    ggplot(aes(pub_year, color = gender_attr)) + 
    geom_freqpoly(binwidth = 1) +
    color_gender +
    labs(x = 'Year', y = 'Author count') +
    scale_x_continuous(limits = c(NA, 2017))
ggsave('07_authors_per_year.png', width = 6, height = 6*3/5)

## Authors active prior to 1920
authors_df %>%
    count(pub_year, family, given, gender_attr) %>%
    filter(pub_year < 1920) %>%
    group_by(family, given, gender_attr) %>%
    summarize(n = sum(n)) %>%
    arrange(desc(n))

## Fraction of women authors per year
authors_df %>%
    count(pub_year, family, given, gender_attr) %>%
    group_by(pub_year) %>%
    summarize(frac_f = sum(gender_attr == 'f') / n()) %>%
    ggplot(aes(pub_year, frac_f)) + 
    geom_line(color = 'red', linetype = 'dashed', alpha = .7) +
    geom_line(color = 'red', 
              data = function (df) {filter(df, pub_year >= 1950)}) +
    scale_x_continuous(limits = c(NA, 2017)) +
    scale_y_continuous(labels = scales::percent_format()) +
    labs(x = 'Year', y = 'Women authors')
ggsave('07_frac_women.png', width = 6, height = 6*3/5)

## Women authors active prior to 1955
authors_df %>%
    filter(pub_year < 1955, gender_attr == 'f') %>%
    count(family, given) %>%
    arrange(desc(n))

## Women authors active 1955-1969
authors_df %>%
    filter(pub_year >= 1955, pub_year < 1970, gender_attr == 'f') %>%
    count(family, given, pub_year) %>%
    group_by(family, given) %>%
    summarize(n = sum(n), first = min(pub_year), last = max(pub_year)) %>%
    arrange(desc(n)) #%>% View

## Useful code for checking for false positive matches
# authors_df %>%
#     filter(family == 'Cassirer', str_detect(given, 'Eva')) %>%
#     select(title, pub_year, given_orig) %>%
#     arrange(pub_year)


## Papers per author per year
## Absolute time
authors_df %>%
    count(pub_year, family, given, gender_attr) %>%
    group_by(pub_year, gender_attr) %>%
    summarize(n_authors = n(), 
              mean_papers = mean(n),
              sd_papers = sd(n, na.rm = TRUE)) %>%
    mutate(sd_papers = ifelse(!is.na(sd_papers), 
                              sd_papers, 
                              0)) %>%
    mutate(se_papers = sd_papers / n_authors, 
           mean_hi = mean_papers + qnorm(.975)*se_papers, 
           mean_lo = mean_papers + qnorm(.0275)*se_papers) %>% 
    ggplot(aes(pub_year, mean_papers, 
               fill = gender_attr)) + 
    # geom_jitter(alpha = .1) +
    # geom_smooth() +
    # stat_summary(fun.y = mean, fun.args = list(na.rm = TRUE), 
    #              geom = 'line') +
    geom_ribbon(aes(ymin = mean_lo, ymax = mean_hi), 
                alpha = .5) +
    geom_line(aes(color = gender_attr)) +
    color_gender + fill_gender +
    scale_x_continuous(limits = c(NA, 2017)) +
    labs(x = 'Year', y = 'Mean number of papers per author')
ggsave('07_author_productivity.png', width = 6, height = 6*3/5)

## Relative to first publication
authors_df %>%
    count(pub_year, family, given, gender_attr) %>%
    group_by(family, given) %>%
    mutate(t = pub_year - min(pub_year), 
           aut = str_c(family, given)) %>%
    ungroup() %>%
    ggplot(aes(t, n, color = gender_attr)) + 
    geom_line(aes(group = aut), alpha = .1) + 
    geom_smooth() +
    facet_wrap(~ gender_attr, scales = 'free')

## Total productivity
authors_df %>%
    count(pub_year, family, given, gender_attr) %>%
    group_by(gender_attr, family, given) %>%
    summarize(n = sum(n), span = max(pub_year) - min(pub_year) + 1) %>%
    ungroup() %>%
    mutate(papers_per_year = n / span) %>%
    ggplot(aes(gender_attr, papers_per_year, 
               color = gender_attr)) + 
    geom_violin(draw_quantiles = c(.5, .9, .99)) +
    geom_jitter(alpha = .1) +
    scale_x_discrete(name = '', breaks = NULL) +
    scale_y_log10(name = 'Total papers per year') +
    color_gender + fill_gender
ggsave('07_total_productivity.png', width = 6, height = 6*3/5)

## Different view of productivity, vs. span
authors_df %>%
    count(pub_year, family, given, gender_attr) %>%
    group_by(gender_attr, family, given) %>%
    summarize(n = sum(n), span = max(pub_year) - min(pub_year) + 1) %>%
    ungroup() %>%
    mutate(papers_per_year = n / span) %>%
    ggplot(aes(papers_per_year, span, color = gender_attr)) + 
    geom_point(aes(label = family)) +
    geom_smooth() +
    color_gender +
    scale_x_log10() +
    facet_wrap(~ gender_attr)

## Who has >8 papers per year?  
## Mostly authors who have whole books/collections in Boston Studies
## The Phil Sci hits are from 1941, when John M. Reiner wrote many (all?) of the book reviews (and apparently never anything else)
authors_df %>%
    count(pub_year, family, given, gender_attr) %>%
    group_by(gender_attr, family, given) %>%
    summarize(n = sum(n), span = max(pub_year) - min(pub_year) + 1) %>%
    ungroup() %>%
    mutate(papers_per_year = n / span) %>%
    filter(papers_per_year > 8) %>%
    left_join(authors_df) %>%
    count(publication_series)
    # filter(publication_series == 'Philosophy of Science') %>% View

## Gender distribution by journal over time
authors_df %>%
    count(pub_year, gender_attr, publication_series) %>%
    group_by(pub_year, publication_series) %>%
    mutate(frac = n / sum(n)) %>%
    filter(gender_attr == 'f') %>%
    ggplot(aes(pub_year, frac, color = gender_attr)) + 
    geom_line() +
    facet_wrap(~ publication_series, scales = 'free') +
    color_gender

## Gender distribution in 6 major journals over time
authors_df %>%
    filter(publication_series %in% c('Philosophy of Science', 'BJPS', 'Biology & Philosophy', 
                                     'Studies in HPS A', 'Studies in HPS B', 'Studies in HPS C')) %>%
    count(pub_year, publication_series, gender_attr) %>%
    group_by(pub_year, publication_series) %>%
    mutate(perc = n / sum(n)) %>%
    filter(gender_attr == 'f') %>%
    ungroup() %>%
    ggplot(aes(pub_year, perc)) +
    geom_line(color = 'red') +
    geom_hline(yintercept = .2, color = 'grey') +
    facet_wrap(~ publication_series, scales = 'free') +
    scale_x_continuous(limits = c(NA, 2017)) +
    scale_y_continuous(labels = scales::percent_format()) +
    labs(x = 'Year', y = 'Women authors')

## All journals is hard to read
# authors_df %>%
#     count(pub_year, gender_attr, publication_series, 
#           publication_group) %>%
#     group_by(pub_year, publication_series) %>%
#     mutate(perc = n / sum(n)) %>%
#     filter(gender_attr == 'f') %>%
#     ungroup() %>%
#     ggplot(aes(pub_year, perc, color = publication_group)) + 
#     geom_line() +
#     geom_hline(yintercept = .2, color = 'grey10') +
#     facet_wrap(~ publication_series, scales = 'free') +
#     scale_color_brewer(palette = 'Set1')


