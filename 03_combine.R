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

journal_pubs = read_rds('01_papers.rds') %>%
    filter(!duplicated(.))
book_pubs = read_rds('02_springer_books.rds') %>%
    rename(doi = DOI, isbn = ISBN, issn = ISSN, url = URL)
mn_pubs = readxl::read_xlsx('00_Minnesota.xlsx') %>%
    mutate_at(vars(issued, volume), as.character) %>%
    nest(.key = 'author', given, family)

## Canonical journal and book series titles
canonical_titles = read_csv('00_canonical_titles.csv')

# setdiff(names(journal_pubs), names(book_pubs))
# setdiff(names(book_pubs), names(journal_pubs))

## Combine dataframes --------------------
pubs_df = bind_rows(journal_pubs, book_pubs, mn_pubs) %>%
    mutate(pub_date = parse_date_time(issued, 
                                      orders = c('ym', 'y', 'ymd')), 
           pub_year = as.integer(year(pub_date))) %>%
    ## Replace CrossRef journal titles with canonical versions
    left_join(canonical_titles) %>%
    mutate(publication_series = case_when(!is.na(pub_canonical) ~ pub_canonical, 
                                          TRUE ~ NA_character_)) %>%
    select(-pub_canonical, -n)

# ggplot(pubs_df, aes(pub_year, color = publication_series)) +
#     geom_freqpoly(binwidth = 1, position = 'stack')

## Reshape to author-level df --------------------
authors_df = pubs_df %>%
    ## Drop `link` because it messes w/ unnesting authors
    select(-link) %>%
    ## Remove rows w/ NULL author values
    filter(map_lgl(author, negate(is.null))) %>%
    ## Unnest authors
    unnest(author) %>%
    ## Add back rows w/ NULL author values
    right_join(pubs_df) %>%
    ## This brought `author` and `link` back
    select(-author, -link)

author_counts = authors_df %>%
    select(doi, publication_group, family, given) %>%
    filter(!duplicated(.), !is.na(publication_group)) %>%
    count(family, given, publication_group) %>%
    spread(publication_group, n, fill = 0L) %>%
    arrange(family)

## 285 papers from Springer journals have encoding errors
## cf <https://github.com/CrossRef/rest-api-doc/issues/67>
authors_df %>% 
    filter(str_detect(given, '\ufffd') | 
               str_detect(family, '\ufffd')) %>% 
    pull(container.title) %>% 
    table()

## Output --------------------

write_rds(pubs_df, path = '03_publications.rds')
write_rds(authors_df, path = '03_authors.rds')
author_counts %>%
    filter(!str_detect(given, '\ufffd') & 
               !str_detect(family, '\ufffd')) %>% 
    write_excel_csv(path = '03_names.csv')


