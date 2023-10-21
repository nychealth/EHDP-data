
library(writexl)

pre_refactor <- dir_info("indicators/data")

post_refactor <- dir_info("indicators/data")

pre_refactor_2 <- pre_refactor %>% select(path, pre_size = size)
post_refactor_2 <- post_refactor %>% select(path, post_size = size)

pre_post_refactor <- 
    left_join(
        pre_refactor_2,
        post_refactor_2
    ) %>% 
    mutate(
        pre_post_size_diff = pre_size - post_size,
        pre_post_size_prop = (1 - ((pre_size - post_size)/pre_size)) * 100
    )

View(pre_post_refactor)

write_rds(pre_post_refactor, "indicators/pre_post_refactor_size_diff.rds")
write_xlsx(pre_post_refactor, "indicators/pre_post_refactor_size_diff.xlsx")

