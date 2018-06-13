## This script draws samples from the deduplicated name lists for verification purposes
## False positives:  Two distinct individuals who are assigned the same canonical name
## False negatives:  A single individual who has multiple canonical names

## Setup ----
library(tidyverse)
set.seed(42)

## Number of names to draw in each sample
n = 100

## Load dedup'ed name list
name_df = read_csv('04_names_verif.csv')

## Samples to look for false positives ----
## Strategy:  Draw a sample of canonical names (assigned to multiple original names).  Check for canonical names assigned to multiple distinct individuals. 
canonical_count_1p = name_df %>%
    count(`Canonical Family`, `Canonical Given`) %>%
    filter(n > 1)

fpos_1 = sample_n(canonical_count_1p, n)
fpos_2 = sample_n(canonical_count_1p, n)

fpos_1 %>%
    inner_join(name_df) %>%
    arrange(`Canonical Family`, `Canonical Given`) %>%
    select(`Canonical Family`, `Canonical Given`, 
           `Orig Family`, `Orig Given`) %>%
    write_csv('05_fpos_1.csv')
fpos_2 %>%
    inner_join(name_df) %>%
    arrange(`Canonical Family`, `Canonical Given`) %>%
    select(`Canonical Family`, `Canonical Given`, 
           `Orig Family`, `Orig Given`) %>%
    write_csv('05_fpos_2.csv')


## Samples to look for false negatives ----
## Strategy:  Draw a sample of canonical names that only occur once.  Draw all matching original family names and look for matchings that should have been made.  
## Checking false negatives is much harder, bc they can be produced by processes such as misspelling, displaced middle names
canonical_count_1 = name_df %>%
    count(`Canonical Family`, `Canonical Given`) %>%
    filter(n == 1)

fneg_1 = sample_n(canonical_count_1, n)
fneg_2 = sample_n(canonical_count_1, n)

fneg_1 %>%
    inner_join(name_df) %>%
    select(`Orig Family`) %>%
    inner_join(name_df) %>%
    arrange(`Orig Family`, `Orig Given`) %>%
    write_csv('05_fneg_1.csv')
fneg_2 %>%
    inner_join(name_df) %>%
    select(`Orig Family`) %>%
    inner_join(name_df) %>%
    arrange(`Orig Family`, `Orig Given`) %>%
    write_csv('05_fneg_2.csv')



