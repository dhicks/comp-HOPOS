## This script assembles the various pieces to build the dataset
library(tidyverse)

library(UNF)

library(assertthat)
library(tictoc)

data_folder = '../data/'
unf_tz = 'UTC'  ## Timezone used in generating UNFs

## Columns to drop for the release
drop_cols = c('member', 'prefix', 'score', 'source', 
              'URL',
              'subject', 'archive', 
              'authenticated.orcid', 
              'affiliation1.name', 'affiliation2.name', 
              'affiliation3.name', 'affiliation4.name', 
              'name', 'funder', 'assertion')

## Load data ----
authors_unfltd = read_rds(str_c(data_folder, '03_authors.rds')) %>%
    filter(!duplicated(.))
names_df = read_csv(str_c(data_folder, '04_names_verif.csv'), 
                    na = 'Ignored') %>%
    filter(!duplicated(.)) %>%
    mutate(`Canonical Family` = ifelse(is.na(`Canonical Family`), 
                                       `Orig Family`, 
                                       `Canonical Family`), 
           `Canonical Given` = ifelse(is.na(`Canonical Given`), 
                                       `Orig Given`, 
                                       `Canonical Given`))

phil_sci = read_rds(str_c(data_folder, '06_phil_sci.Rds'))

gender_df = read_rds(str_c(data_folder, '06_gender.Rds')) %>%
    ## For IP reasons, these columns can't be publicly released
    select(-prob_f_namsor, -gender_namsor, 
           -prob_f_genderize, -gender_genderize) %>%
    rename(prob_f_avg = avg)


## Load manual fixes ----
drop_df = read_rds(str_c(data_folder, '00_drop.Rds'))
drop_authors_df = read_rds(str_c(data_folder, '00_drop_authors.Rds'))
name_change_df = read_rds(str_c(data_folder, '00_name_change.Rds'))
fix_gender_df = read_rds(str_c(data_folder, '00_fix_gender.Rds'))


## Functions ----
## If col1 is NA, use col2; otherwise use col1
keep_or_patch = function(col1, col2) {
    return(ifelse(is.na(col1), col2, col1))
}

## Convert the UNF objects created by unf() into a tidy format
as_tibble.UNF = function(obj) {
    attributes = attributes(obj)
    return(tibble(
        unf = obj$unf, 
        hash = list(obj$hash), 
        unflong = obj$unflong, 
        formatted = obj$formatted, 
        version = attributes$version, 
        digits = attributes$digits, 
        characters = attributes$characters, 
        truncation = attributes$truncation
    ))
}


## Combine ----
## Combine author-level metadata, canonical names, and gender attribution
authors_full = authors_unfltd %>%
    ## Drop columns
    mutate(url = keep_or_patch(url, URL)) %>% 
    select(-one_of(drop_cols)) %>% 
    ## Canonical names
    left_join(names_df, 
              by = c('family' = 'Orig Family', 
                     'given' = 'Orig Given')) %>% 
    rename(family_orig = family, 
           given_orig = given) %>% 
    ## Springer had some encoding errors that caused problems w/ deduping
    mutate(family = keep_or_patch(`Canonical Family`, family_orig), 
           given = keep_or_patch(`Canonical Given`, given_orig)) %>%
    ## Gender attribution
    left_join(gender_df) %>% 
    ## Manual name fixes
    left_join(name_change_df, by = c('family', 'given')) %>% 
    mutate(family = keep_or_patch(family.manual, family), 
           given = keep_or_patch(given.manual, given)) %>% 
    select(-contains('manual')) %>% 
    ## Manual gender fixes
    left_join(fix_gender_df, by = c('family', 'given', 
                                    'gender_attr')) %>% 
    select(-gender_attr, everything(), gender_attr) %>% 
    mutate(gender_attr = keep_or_patch(gender_attr.manual, 
                                       gender_attr)) %>% 
    ## Recode 'f' as 'w'
    rename(prob_w_blevins = prob_f_blevins, 
           prob_w_avg = prob_f_avg) %>% 
    mutate_at(vars(gender_blevins, gender_attr, gender_attr.manual), 
              list(~str_replace(., 'f', 'w'))) %>% 
    ## Lowercase all variable names
    rename_all(tolower)

## Filter down to philosophers of science
authors_phs = inner_join(authors_full, phil_sci) %>% 
    anti_join(drop_authors_df) %>% 
    anti_join(drop_df)


## Data validation ----
## No list columns in author-level
authors_full %>% 
    as.list() %>% 
    map_lgl(is.list) %>% 
    {!.} %>% 
    all() %>% 
    assert_that(msg = 'List columns in author_full')

## All phil sci authors have a gender
authors_phs %>% 
    pull(gender_attr) %>% 
    is.na() %>% 
    {!.} %>% 
    all() %>% 
    assert_that(msg = 'Not all phil sci authors have a gender')

## All phil sci authors have a family name
authors_phs %>% 
    pull(family) %>% 
    is.na() %>% 
    {!.} %>% 
    all() %>% 
    assert_that(msg = 'Not all phil sci authors have a family name')
    

## Publication-wise formats ----
## 30 sec
tic()
pubs_full = nest(authors_full, given_orig:gender_attr, 
                 .key = 'author_data') %>%
    mutate(n_authors = map_int(author_data, nrow))
toc()

pubs_full_csv = select_if(pubs_full, negate(is.list))

## 9 sec
tic()
pubs_phs = nest(authors_phs, given_orig:gender_attr, 
                .key = 'author_data') %>%
    mutate(n_authors = map_int(author_data, nrow))
toc()

pubs_phs_csv = select_if(pubs_phs, negate(is.list))


## UNFs ----
## 146 sec
tic()
unf_df = list('authors-full-both' = authors_full, 
              'pubs-full-Rds' = pubs_full, 
              'authors-phil sci-both' = authors_phs,
              'pubs-phil sci-Rds' = pubs_phs, 
              'pubs-phil sci-csv' = pubs_phs_csv
) %>%  
    map(unf, version = 6, digits = 3, 
        timezone = unf_tz) %>% 
    map_dfr(as_tibble, .id = 'dataset') %>% 
    separate(dataset, into = c('format', 'size', 'file_format'), 
             sep = '-') %>% 
    mutate(timezone = unf_tz) %>% 
    select(-unflong, everything(), unflong)
toc()



## Output ----
## Column names - useful for data dictionary
authors_full %>%
    names() %>%
    write_lines(str_c(data_folder, '07_cols.txt'))

## UNFs
unf_df %>% 
    select_if(negate(is.list)) %>% 
    write_csv(str_c(data_folder, '07_unf.csv'))

## Author-wise formats
write_rds(authors_full, str_c(data_folder, '07_authors_full.Rds'))
write_csv(authors_full, str_c(data_folder, '07_authors_full.csv'))
write_rds(authors_phs, str_c(data_folder, '07_authors_philsci.Rds'))
write_csv(authors_phs, str_c(data_folder, '07_authors_philsci.csv'))

## Publication-wise formats
write_rds(pubs_full, str_c(data_folder, '07_publications_full.Rds'))
write_csv(pubs_full_csv, str_c(data_folder, '07_publications_full.csv'))
write_rds(pubs_phs, str_c(data_folder, '07_publications_philsci.Rds'))
write_csv(pubs_phs_csv, str_c(data_folder, '07_publications_philsci.csv'))
