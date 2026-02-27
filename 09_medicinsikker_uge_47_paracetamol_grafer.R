library(tidyverse)
library(glue)
# library(prophet)
library(slider)
devtools::load_all()
# library(duckdb)
# library(duckplyr)
# library(arrow)
# library(conflicted)
# conflict_prefer("filter", "duckplyr")
# 
# methods_overwrite()

# Gør klar ----------------------------------------------------------------

config <- config::get()
filsti <- paste0(config$raadata_sti,"medicinsikkert_hospital/")
load(paste0(config$r_sti, "database_organisation/org.RData")) 

org <- org |> janitor::clean_names()
uge_slut <- floor_date(today(), unit = "week", getOption("lubridate.week.start", 1)) 

paste2 <- function(...,sep=", ") {
  L <- list(...)
  L <- lapply(L,function(x) {x[is.na(x)] <- ""; x})
  gsub(paste0("(^",sep,"|",sep,"$)"),"",
       gsub(paste0(sep,sep),sep,
            do.call(paste,c(L,list(sep=sep)))))
}

# load("medicineringsdetaljer.RData") 

scanning_detaljer <- arrow::read_parquet(paste0(config$onedrive_r_sti,"medicinsikkert_hospital/","medicineringsdetaljer_2020-2025.parquet"))

# load(paste0(config$beregnede_data_sti, "/sp_import.RData"))

sengedage <- arrow::read_parquet(paste0(filsti, "/sengedage_bfh_pr_dag.parquet")) |> 
  transmute(
    indikator,
    enhed = str_remove(enhed, "BFH "),
    # afdeling = "BISPEBJERG OG FREDERIKSBERG HOSPITAL",
    # afsnit = NA_character_,
    observation_dato = as_date(cut(dmy(dato), "month")),
    sengedage = as.numeric(taeller)
  ) |> left_join(org)

# |> 
#   summarise(
#     taeller0 = sum(taeller, na.rm = TRUE),
#     .by = c(indikator, afdeling, afsnit, observation_dato)
#   )
  


dat <- scanning_detaljer |> 
  filter(atc == "N02BE01") |> 
  mutate(administrationsafsnit = str_remove(administrationsafsnit_oprindelig, "BFH ")) |> 
  # group_by(uge, frekvenstype) |> 
  left_join(org, by = c("administrationsafsnit" = "enhed")) %>% 
  transmute(observation = as_date(cut(administrationstid, "month")),
            indikator = paste0("paracetamol ", frekvenstype),
            # enhed = rekvirentkode_provetgnngsstd,
            afdeling = afdeling.y,
            afsnit = afsnit.y,
  ) %>% 
  group_by(indikator, observation, afdeling, afsnit) %>% 
  summarise(taeller0 = n(),
            naevner0 = NA) %>% 
  ungroup() %>% 
  filter(!is.na(afdeling))


aggreger_data_hierarki <- function(data, aggregeringsvariabel, afdeling, afsnit, ...) {
  
  # beregn afsnit
  aggreger_afsnitsniveau <- data |>
    summarise(taeller0 = sum(.data[[aggregeringsvariabel]], na.rm = TRUE), .by = c(afdeling, afsnit, ...)) |>
    ungroup()
  
  # beregn afdelinger
  aggreger_afdelingsniveau <- data |>
    summarise(taeller0 = sum(.data[[aggregeringsvariabel]], na.rm = TRUE), .by = c(afdeling, ...)) |>
    ungroup() |>
    mutate(afsnit = NA_character_ )
  
  # beregn hospitalet
  aggreger_hospitalsniveau <- data |>
    summarise(taeller0 = sum(.data[[aggregeringsvariabel]], na.rm = TRUE), .by = c(...)) |>
    ungroup() |>
    mutate(afdeling = "BISPEBJERG OG FREDERIKSBERG HOSPITAL",
           afsnit = NA_character_ )
  
  aggregeret_datasaet <- aggreger_hospitalsniveau |> 
    # bind_rows(aggreger_afsnitsniveau,
    #                                aggreger_afdelingsniveau,
    #                                aggreger_hospitalsniveau) |>
    
    complete(nesting(afdeling, afsnit), ..., fill = list(taeller0 = 0)) |> 
    mutate(enhed = paste2(afdeling, afsnit)) 
  
  return(aggregeret_datasaet)
}

dat_sengedage <- aggreger_data_hierarki(sengedage, "sengedage", afdeling, afsnit, observation_dato) |>
  rename(sengedage = taeller0) |>
  mutate(sengedage = sengedage/100)




faerdigt_datasaet_antal <- aggreger_data_hierarki(dat, "taeller0", afdeling, afsnit, observation, indikator) |> 
  filter(observation >= as_date("2022-01-01")) |> 
  mutate(observation_dato = as_date(observation),
         observation = as.character(observation)) %>%
  filter(observation_dato < as_date(cut(Sys.Date(), "month")))

faerdigt_datasaet_rate_samlet <- faerdigt_datasaet_antal |> 
  mutate(indikator = "paracetamol samlet rate") |>
  # mutate(indikator = paste0(indikator, " rate")) |> 
  # mutate(indikator = if_else(indikator == "paracetamol samlet antal rate", "paracetamol samlet rate", indikator)) |> 
  summarise(taeller0 = sum(taeller0, na.rm = TRUE), .by = c(indikator, afdeling, afsnit, observation, observation_dato)) |> 
  left_join(dat_sengedage)  |> 
  filter(observation_dato < floor_date(today(), unit = "month", getOption("lubridate.week.start", 1))- weeks(1))

faerdigt_datasaet_rate <- faerdigt_datasaet_antal |> 
  # mutate(indikator = "paracetamol samlet rate") |>
  mutate(indikator = paste0(indikator, " rate")) |>
  mutate(indikator = if_else(indikator == "paracetamol samlet antal rate", "paracetamol samlet rate", indikator)) |> 
  summarise(taeller0 = sum(taeller0, na.rm = TRUE), .by = c(indikator, afdeling, afsnit, observation, observation_dato)) |> 
  left_join(dat_sengedage)  |> 
  filter(observation_dato < floor_date(today(), unit = "month", getOption("lubridate.week.start", 1))- weeks(1)) |> bind_rows(faerdigt_datasaet_rate_samlet)


  

faerdigt_datasaet_antal <- faerdigt_datasaet_antal |> bind_rows(faerdigt_datasaet_antal |> 
  mutate(indikator = "paracetamol samlet antal") |> 
    mutate(indikator = as.character(indikator)) |> 
  summarise(taeller0 = sum(taeller0, na.rm = TRUE), .by = c(indikator, afdeling, afsnit, observation, observation_dato)))  |> 
  mutate(naevner0 = NA) 
  

faerdigt_datasaet <- bind_rows(faerdigt_datasaet_antal, faerdigt_datasaet_rate) |> 
  transmute(
  indikator,
  afdeling = factor(afdeling),
  afsnit = factor(afsnit),
  observation_dato,
  taeller0,
  naevner0 = case_when(
    str_detect(indikator, "rate") ~ sengedage,
    TRUE ~ NA_integer_)
)



paracetamol_flergangs_PN_rate <- faerdigt_datasaet |> 
  filter(indikator == "paracetamol flergangs-PN rate")

paracetamol_flergangs_fast_rate <- faerdigt_datasaet |> 
  filter(indikator == "paracetamol flergangs-fast rate")

paracetamol_samlet_rate <- faerdigt_datasaet |> 
  filter(indikator == "paracetamol samlet rate")


create_spc_chart(
  data = paracetamol_flergangs_PN_rate,
  x = observation_dato,
  y = taeller0,
  n = naevner0,
  chart_type = "run",
  # y_axis_unit = "count",
  chart_title = "**PN-forbrug af paracetamol**",
  subtitle = "BISPEBJERG OG FREDERIKSBERG HOSPITAL",
  ylab = "ADM. PR 100 SENGEDAGE",
  part = c(16, 32),  # Phase split after 12 months
)


BFHcharts::create_spc_chart(
  data = paracetamol_flergangs_fast_rate,
  x = observation_dato,
  y = taeller0,
  n = naevner0,
  chart_type = "run",
  # y_axis_unit = "count",
  chart_title = "**Fast forbrug af paracetamol**",
  subtitle = "BISPEBJERG OG FREDERIKSBERG HOSPITAL",
  ylab = "ADM. PR 100 SENGEDAGE",
  part = c(11, 26, 35),
) 

BFHcharts::create_spc_chart(
  data = paracetamol_samlet_rate,
  x = observation_dato,
  y = taeller0,
  n = naevner0,
  chart_type = "run",
  # y_axis_unit = "count",
  chart_title = "**Samlet forbrug af paracetamol**",
  subtitle = "BISPEBJERG OG FREDERIKSBERG HOSPITAL",
  ylab = "ADM. PR 100 SENGEDAGE",
  part = c(11, 26)#, 35),
  # target_text = ">="
) 




