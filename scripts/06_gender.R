## Filter down to philosophers of science and attribute gender
##
## This script accesses files in the repository available at <https://github.com/cblevins/Gender-ID-By-Time>.  To use the script as configured, clone this script into the working directory.  
## This script also accesses APIs for two subscription services, [NamSor](http://www.namsor.com/) and [genderize.io](https://genderize.io/).  
## After subscribing to those services, create a file `api_keys.R` in the working directory, and add API keys with the following format:  
## ```
## namsor_key = 'stringofcharacters'
## namsor_user = 'namsor.com/e@mail.com/12345'
## genderize.io_key = 'otherstringofcharacters'
## ```

## Setup ----
library(tidyverse)

source('api_keys.R')

authors_df_unfltd = read_rds('../data/03_authors.rds') %>%
    filter(!is.na(family))
names_df = read_csv('../data/04_names_verif.csv', na = 'Ignored') %>%
    filter(!duplicated(.)) %>%
    mutate(`Canonical Family` = ifelse(is.na(`Canonical Family`), 
                                       `Orig Family`, 
                                       `Canonical Family`), 
           `Canonical Given` = ifelse(is.na(`Canonical Given`), 
                                      `Orig Given`, 
                                      `Canonical Given`))

## Combine author-level metadata and canonical names
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
    ## Erkenntnis is primary prior to 1941
    mutate(publication_group = case_when(
        publication_series == 'Erkenntnis' & pub_year < 1941 ~ 'primary', 
        TRUE ~ publication_group))

## Filter down to "philosophers of science" 
phil_sci = authors_df %>%
    count(given, family, publication_group) %>%
    filter(publication_group == 'primary', n >= 2) %>%
    select(given, family) %>%
    inner_join(authors_df)

## Clean "given," removing initials and selecting what appears to be the first full name
phil_sci = phil_sci %>%
    select(given) %>%
    filter(!duplicated(.)) %>%
    mutate(split = str_split(given, ' ')) %>%
    unnest() %>%
    filter(!duplicated(.)) %>%
    mutate(len = str_length(split)) %>%
    filter(len > 1) %>%
    group_by(given) %>%
    filter(split == first(split)) %>%
    ungroup() %>%
    select(-len) %>%
    rename(for_gender_attr = split) %>%
    right_join(phil_sci)

phil_sci %>%
    select(given, family) %>%
    filter(!duplicated(.)) %>%
    write_rds('../data/06_phil_sci.Rds')

## Num. philosophy of science articles published in analytic journals
# phil_sci %>%
#     select(doi, container.title:pub_year,
#            publication_group, publication_series) %>%
#     filter(publication_group == 'analytic') %>%
#     filter(!duplicated(.)) %>%
#     ggplot(aes(pub_year)) +
#     geom_point(stat = 'count') +
#     geom_line(stat = 'count')

## Num. phil sci articles published across pub groups
# phil_sci %>%
#     select(doi, container.title:pub_year, 
#            publication_group, publication_series) %>%
#     filter(!duplicated(.)) %>%
#     count(pub_year, publication_group) %>%
#     ggplot(aes(pub_year, n, color = publication_group)) +
#     geom_line()

## Frac. phil sci articles across pub groups
## This is a nice one for showing that phil sci is gradually separating from analytic phil
# phil_sci %>%
#     select(doi, container.title:pub_year, 
#            publication_group, publication_series) %>%
#     filter(!duplicated(.)) %>%
#     count(pub_year, publication_group) %>%
#     group_by(pub_year) %>%
#     mutate(frac = n / sum(n)) %>%
#     ungroup() %>%
#     ggplot(aes(pub_year, frac, color = publication_group)) +
#     geom_line()


## Cameron Blevins: Gender ID by time ----
## <https://github.com/cblevins/Gender-ID-By-Time>

## Estimated yob is 30±5 years prior to first paper
author_first_pub = phil_sci %>%
    group_by(for_gender_attr, given, family) %>%
    summarize(first_pub = min(pub_year, na.rm = TRUE)) %>%
    ungroup() %>%
    mutate(yob_low = first_pub - 30 - 5, 
           yob_high = first_pub - 30 + 5)

## Load SSA YOB files
yob_folder = '../Gender-ID-By-Time/ReferenceData'
yob_files = list.files(yob_folder)
names(yob_files) = str_extract(yob_files, '[0-9]+')

## Takes a second
yob_df = yob_files %>%
    str_c(yob_folder, '/', .) %>% 
    `names<-`(names(yob_files)) %>%
    # head() %>%
    map(read_csv, col_names = c('given', 'gender', 'count')) %>%
    bind_rows(.id = 'yob') %>%
    rename(for_gender_attr = given)

## Takes a couple seconds
gender_blevins = author_first_pub %>%
    left_join(yob_df) %>%
    filter((yob_low <= yob & yob <= yob_high) | is.na(yob)) %>%
    group_by(for_gender_attr, given, family, gender) %>%
    summarize(count = sum(count)) %>%
    spread(gender, count, fill = 0) %>%
    select(-`<NA>`) %>%
    mutate(n = F+M, 
           prob_f_blevins = ifelse(n > 0, F / n, NA),
           gender_blevins = case_when(prob_f_blevins < .25 ~ 'm', 
                                      prob_f_blevins > .75 ~ 'f', 
                                      TRUE ~ 'indeterminate')) %>%
    ungroup()

# ggplot(gender_blevins, aes(prob_f)) + stat_ecdf() + geom_rug()
# 
# gender_blevins %>%
#     filter(prob_f > .25, prob_f < .75) %>% View
# 
# phil_sci %>%
#     left_join(gender_blevins) %>%
#     ggplot(aes(pub_year, fill = gender_blevins)) +
#     geom_bar(width = 1)
# 



## NamSor and nomine ----
## <https://github.com/cdcrabtree/nomine>
# library(nomine)
## Currently nomine raises an exception when the name contains spaces
## <https://github.com/cdcrabtree/nomine/issues/1>
# phil_sci %>%
#     count(given, family) %>%
#     sample_n(10) %>%
#     {with(., get_gender(given, family, 
#                         secret = namsor_key, user = namsor_user))}

## One-name-at-a-time version
namsor = function(given, family, namsor_key = NULL, namsor_user = NULL) {
    query_url = str_c('https://api.namsor.com/onomastics/api/json/gender/',
                      RCurl::curlEscape(given), '/', RCurl::curlEscape(family))
    full_url = str_c(query_url, '?key1=', namsor_key,
                     '&key2=', namsor_user)
    print(query_url)
    response = RCurl::getURL(full_url)
    json = jsonlite::fromJSON(response)
    json = jsonlite:::null_to_na(json)
    return(json)
}
# 
# phil_sci %>%
#     select(given, family) %>%
#     filter(!duplicated(.)) %>%
#     .[100:110,] %>%
#     transpose() %>%
#     map(~ namsor(.$given, .$family)) %>%
#     bind_rows()

## List/batched version
## NB API will raise an error w/ > 1k names
## ************ NB This can get expensive quickly! **************
## Make sure the namsor account is upgraded BEFORE running on a large list! 
namsor_list = function(names_df) {
    query_url = str_c('https://api.namsor.com/onomastics/api/json/genderList')
    header = c('Accept' = 'application/json', 
               'X-Channel-Secret' = namsor_key, 
               'X-Channel-User' = namsor_user)
    names_json = names_df %>%
        select(firstName = given, lastName = family) %>%
        filter(!duplicated(.)) %>%
        mutate(id = row_number()) %>%
        list('names' = .) %>%
        jsonlite::toJSON()
    
    response = RCurl::basicTextGatherer()
    result = RCurl::curlPerform(url = query_url, httpheader = header, postfields = names_json, writefunction = response$update)
    
    response_df = response$value() %>%
        jsonlite::fromJSON() %>%
        .$names %>%
        rename(given = firstName, family = lastName)
    return(response_df)
}

namsor_file = '../data/06_namsor.Rds'
if (!file.exists(namsor_file)) {
    chunks = phil_sci %>%
        count(given, family) %>%
        filter(complete.cases(.)) %>%
        mutate(row_num = row_number(), 
               chunk = as.integer(row_num %/% 1000)) %>%
        plyr::dlply('chunk', identity)
    
    gender_namsor = map_dfr(chunks, namsor_list)
    gender_namsor = gender_namsor %>%
        ## Rescale output variables
        mutate(gender = case_when(gender == 'male' ~ 'm', 
                                  gender == 'female' ~ 'f', 
                                  gender == 'unknown' ~ 'indeterminate'), 
               scale = (scale + 1)/2) %>%
        rename(gender_namsor = gender, 
               prob_f_namsor = scale)
    
    write_rds(gender_namsor, namsor_file)
} else {
    gender_namsor = read_rds(namsor_file)
}

ggplot(gender_namsor, aes(prob_f_namsor)) + 
    stat_ecdf() + geom_rug(aes(color = gender_namsor))



## genderize.io and genderizeR ----
# library(genderizeR)
## <https://github.com/kalimu/genderizeR>
## This is really designed for names embedded in blocks of text

# genderize = function (given, api_key = NULL) {
#     query_url = str_c('https://api.genderize.io/?name=', given)
#     if (!is.null(api_key)) {
#         query_url = str_c(query_url, '&apikey=', api_key)
#     }
#     response = RCurl::getURL(query_url)
#     json = jsonlite::fromJSON(response, simplifyDataFrame = TRUE)
#     json = jsonlite:::null_to_na(json)
#     return(json)
# }
# ## 8.793 sec / 25 names -> ~14 minutes for all 2384 names
# tictoc::tic()
# thing = phil_sci %>%
#     filter(!is.na(for_gender_attr)) %>%
#     pull(for_gender_attr) %>%
#     unique() %>%
#     .[1:25] %>%
#     map_dfr(genderize) %>%
#     rename(for_gender_attr = name)
# tictoc::toc()

## Batch/list version
genderize_list = function(given, api_key = NULL) {
    names = str_c('name[]=', given, collapse = '&')
    query_url = str_c('https://api.genderize.io/?', names)
    if (!is.null(api_key)) {
        query_url = str_c(query_url, '&apikey=', api_key)
    }
    response = RCurl::getURL(query_url)
    json = jsonlite::fromJSON(response, simplifyDataFrame = TRUE)
    json = jsonlite:::null_to_na(json)
    return(json)
}

chunks_genderize = phil_sci %>%
    filter(!is.na(for_gender_attr)) %>%
    count(for_gender_attr) %>%
    mutate(chunk = row_number() %/% 10) %>%
    plyr::dlply('chunk', identity) %>%
    map(pull, for_gender_attr)

## 1.042 sec / 3 chunks -> ~45 sec for all 128 chunks
# tictoc::tic()
# map(chunks_genderize[1:3], genderize_list)
# tictoc::toc()

genderize_file = '../data/06_genderize.Rds'
if (!file.exists(genderize_file)) {
    # tictoc::tic()
    gender_genderize = chunks_genderize %>%
        map_dfr(genderize_list, api_key = genderize.io_key)
    # tictoc::toc()
    
    gender_genderize = gender_genderize %>%
        ## Rescale output variables
        mutate(gender = case_when(gender == 'male' ~ 'm',
                                  gender == 'female' ~ 'f',
                                  is.na(gender) ~ 'indeterminate'),
               probability = ifelse(gender == 'm', 1-probability, probability)) %>%
        rename(prob_f_genderize = probability, 
               gender_genderize = gender,
               for_gender_attr = name)
    
    write_rds(gender_genderize, genderize_file)
} else {
    gender_genderize = read_rds(genderize_file)
}


## Combine ----

gender_combined = phil_sci %>%
    select(for_gender_attr, given, family) %>%
    filter(!duplicated(.)) %>%
    left_join(gender_blevins) %>% 
    select(-`F`, -M, -n) %>%
    left_join(gender_namsor) %>%
    select(-id) %>%
    left_join(gender_genderize) %>%
    select(-count) %>% 
    rowwise() %>%
    mutate(avg = mean(c(prob_f_blevins, 
                        prob_f_namsor,
                        prob_f_genderize), 
                      na.rm = TRUE)) %>%
    ungroup() %>%
    mutate(gender_attr = case_when(avg < .25 ~ 'm', 
                                   avg > .75 ~ 'f', 
                                   TRUE ~ 'indet'))

write_rds(gender_combined, '../data/06_gender.Rds')

# ggplot(gender_combined, aes(prob_f_blevins, prob_f_namsor)) + 
#     geom_point() +
#     ggrepel::geom_label_repel(aes(label = str_c(given, ' ', family)), 
#                               data = function (dataf) dataf[abs(dataf$prob_f_blevins - dataf$prob_f_namsor) > .5,]) +
#     theme_bw()

ggplot(gender_combined, aes(avg)) + stat_ecdf()
filter(gender_combined, gender_attr == 'indet') %>% 
    write_csv('../data/06_indeterminate_gender.csv')





