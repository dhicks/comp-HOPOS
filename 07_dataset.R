library(tidyverse)

authors_unfltd = read_rds('03_authors.rds') %>%
    filter(!duplicated(.))
names_df = read_csv('04_names_verif.csv', na = 'Ignored') %>%
    filter(!duplicated(.))

phil_sci = read_rds('06_phil_sci.Rds')

gender_df = read_rds('06_gender.Rds') %>%
    select(-prob_f_namsor, -gender_namsor, 
           -prob_f_genderize, -gender_genderize) %>%
    rename(prob_f_avg = avg)

## Combine author-level metadata, canonical names, and gender attribution
authors_full = authors_unfltd %>%
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
    ## Join gender attribution
    left_join(gender_df)

## Filter down to philosophers of science
authors_phs = inner_join(authors_full, phil_sci)


## Publication-wise formats
pubs_full = nest(authors_full, given_orig:gender_attr, .key = 'author_data')
pubs_phs = nest(authors_phs, given_orig:gender_attr, .key = 'author_data')


## Output ----
## Column names - useful for data dictionary
authors_full %>%
    names() %>%
    write_lines('07_cols.txt')

## Author-wise formats
write_rds(authors_full, '07_authors_full.Rds')
authors_full %>%
    select_if(negate(is.list)) %>%
    write_csv('07_authors_full.csv')
write_rds(authors_phs, '07_authors_philsci.Rds')
authors_phs %>%
    select_if(negate(is.list)) %>%
    write_csv('07_authors_philsci.csv')

## Publication-wise formats
write_rds(pubs_full, '07_publications_full.Rds')
pubs_full %>%
    select_if(negate(is.list)) %>%
    write_csv('07_publications_full.csv')
write_rds(pubs_phs, '07_publications_philsci.Rds')
pubs_phs %>%
    select_if(negate(is.list)) %>%
    write_csv('07_publications_philsci.csv')

