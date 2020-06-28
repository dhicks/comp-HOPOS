## This script combines the upstream data files for further analysis
## Output files:  
## - 03_publications.rds: publication-level metadata
## - 03_authors.rds: author-level metadata
## - 03_names.csv: CSV of pub counts by name, for de-duping
##
## The two rds files contain exactly the same metadata; the `author` column of publications is unnested in `authors`

## Setup --------------------
library(tidyverse)
library(lubridate)

library(tictoc)
library(assertthat)

data_folder = file.path('..', 'data')

journal_pubs = read_rds(file.path(data_folder, '01_papers.rds')) %>%
    filter(!duplicated(.))
book_pubs = read_rds(file.path(data_folder, '02_springer_books.rds')) %>%
    rename(doi = DOI, isbn = ISBN, issn = ISSN, url = URL) %>% 
    mutate()
mn_pubs = readxl::read_xlsx(file.path(data_folder, '00_Minnesota.xlsx')) %>%
    mutate_at(vars(issued, volume), as.character) %>%
    nest(author = c(given, family))

## Canonical journal and book series titles
canonical_titles = read_csv('../data/00_canonical_titles.csv')

# setdiff(names(journal_pubs), names(book_pubs))
# setdiff(names(book_pubs), names(journal_pubs))

## Combine dataframes --------------------
pubs_df = bind_rows(journal_pubs, book_pubs, mn_pubs) %>%
    mutate(pub_date = parse_date_time(issued, 
                                      orders = c('ym', 'y', 'ymd')), 
           pub_year = as.integer(year(pub_date))) %>%
    ## Replace CrossRef journal titles with canonical versions
    left_join(canonical_titles) %>%
    mutate(publication_series = if_else(!is.na(pub_canonical), 
                                        pub_canonical,
                                        publication_series)) %>% 
    select(-pub_canonical, -n) %>% 
    ## Drop some problem columns that we don't need anyways
    select(-link, -funder, -assertion)

## TODO: handle NA publication_series
# assert_that(!any(is.na(pubs_df$publication_series)))

pubs_df %>% 
    count(doi, title) %>% 
    nrow() %>% 
    identical(nrow(pubs_df)) %>% 
    assert_that(msg = 'DOI + title do not uniquely identify documents')


## Reshape to author-level df --------------------
## Rows w/ NULL author values
null_author = pubs_df %>% 
    filter(map_lgl(author, is.null)) %>% 
    select(-author)

## Apparently the new version of unnest is MUCH slower; 
## wall times for 30k rows were ~80 seconds vs. ~1 sec
# message('Expanding author column; can take a few minutes')
tic()
authors_df = pubs_df %>%
    ## Remove rows w/ NULL author values
    anti_join(null_author, by = c('doi', 'title')) %>% 
    # slice(1:30000) %>%
    ## Unnest authors
    unnest_legacy(author) %>%
    ## Add back rows w/ NULL author values
    bind_rows(null_author)
toc()

author_counts = authors_df %>%
    select(doi, publication_group, family, given) %>%
    filter(!duplicated(.), !is.na(publication_group)) %>%
    count(family, given, publication_group) %>%
    spread(publication_group, n, fill = 0L) %>%
    mutate(secondary = secondary + analytic + feminist) %>%
    select(-analytic, -feminist) %>%
    arrange(family)

## 298 papers, mostly from Springer journals, have encoding errors
## cf <https://github.com/CrossRef/rest-api-doc/issues/67>
authors_df %>% 
    filter(str_detect(given, '\ufffd') | 
               str_detect(family, '\ufffd')) %>% 
    count(publication_series) #%>%
    # pull(n) %>% sum()
    

## Output --------------------

write_rds(pubs_df, file.path(data_folder, '03_publications.rds'))
write_rds(authors_df, file.path(data_folder, '03_authors.rds'))

## Python script used in 04 can't handle the encoding errors
author_counts %>%
    filter(!str_detect(given, '\ufffd') & 
               !str_detect(family, '\ufffd')) %>% 
    write_excel_csv(file.path(data_folder, '03_names.csv'))


