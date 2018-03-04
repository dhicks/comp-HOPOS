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

journal_pubs = read_rds('01_papers.rds')
book_pubs = read_rds('02_springer_books.rds')

# setdiff(names(journal_pubs), names(book_pubs))
# setdiff(names(book_pubs), names(journal_pubs))

## Combine dataframes --------------------
pubs_df = bind_rows(journal_pubs, book_pubs) %>%
    mutate(pub_date = parse_date_time(issued, 
                                      orders = c('ym', 'y', 'ymd')), 
           pub_year = as.integer(year(pub_date)))

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
    select(DOI, publication_group, family, given) %>%
    filter(!duplicated(.), !is.na(publication_group)) %>%
    count(family, given, publication_group) %>%
    spread(publication_group, n, fill = 0L) %>%
    arrange(family)

## 285 papers from Springer journals have encoding errors
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


