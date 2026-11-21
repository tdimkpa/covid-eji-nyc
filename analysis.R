# NYC COVID-19 and Environmental Justice Index — spatial analysis
# Author: Tobechi Dimkpa
# Run from the repository root so all paths below resolve relatively.
# Large source files (CDC EJI tract file, ZCTA-tract relationship file,
# MODZCTA and census-tract shapefiles) are not included in this repo;
# see README.md for where to obtain them. Place them in the repo root
# (or adjust the relative paths below) before running.
# Required packages are listed in README.md; install them first —
# this script does not install packages itself.
#
# Step 1: Load our packages:
library(tidycensus)
library(tidyverse)
library(sf)
library(RColorBrewer)
library(classInt)
library(ggspatial)
library(sfhotspot)
library(patchwork)
library(osrm)
library(biscale)
library(sfdep)
library(janitor)
# Working directory: run from the repo root; all paths below are relative.
#Step 3: Import EJI data and filter
eji <- read_csv("New York.csv") %>%
  filter( `COUNTY` %in% c("Bronx", "Kings", "New York", "Queens", "Richmond")) %>%
  janitor:: clean_names() %>%
  mutate(geoid = as.character(geoid))
#Step 4: Convert EJI to modzcta using crosswalk
#Import crosswalk
crosswalkeji <- read_csv("zcta_tract_rel_10.txt") |> 
  clean_names() %>%
  filter(state == "36")

#Join data
eji_weighted <- crosswalkeji |> 
  right_join(eji, by = "geoid") |>
  mutate(weighted_eji = spl_ser * e_totpop) |>
  group_by(zcta5) 

#iMPORT MODZCTA data to convert
modzcta_shapes <-  st_read("modzcta_2010.shp")
# First, rename zcta5 to match column in modzcta_shapes
eji_weighted <- eji_weighted |> 
  rename(MODZCTA = zcta5)

# Join to spatial shape using standard left join
modzcta_eji <- modzcta_shapes |> 
  left_join(eji_weighted, by = "MODZCTA")

#Base map
# Apply a theme
ggplot() +
  geom_sf(data = modzcta_eji,
          fill = "cornflowerblue",  
          color = "black",  
          linewidth = 0.05,  
          alpha = .5) +
  theme_void()
# Create the map
# Jenks natural breaks (use style = "jenks")
quant_breaks <- classIntervals(modzcta_eji$spl_ser, n = 4, style = "quantile")$brks
print(quant_breaks)
ggplot() +
  geom_sf(data = modzcta_eji, 
          aes(fill = spl_ser), 
          color = "black", 
          linewidth = 0.2, 
          na.value = "lightgray") +
  
  # Use a continuous scale with custom breaks and labels
  scale_fill_fermenter(
    palette = "Reds",
    direction = 1,
    guide = "legend",
    breaks = quant_breaks,
    name = "Percentile Rank"
  ) +
  
  guides(fill = guide_legend(
    reverse = TRUE,
    title.position = "top",
    title.hjust = 0.5
  )) +
  
  # Title
  labs(title = "Environmental Justice Burden by Modified ZCTA",
       caption = "Author: Tobechi Dimkpa \nSources: CDC EJI \nDate: March 25,2025") +
  
  # Layout adjustments
  theme_void() +
  theme(plot.title = element_text(size = 13,
                                  family  = "Avenir",
                                  vjust = 3,
                                  hjust = 0.10),
        plot.title.position = "plot",
        legend.title = element_text(size = 10),
        legend.position = c(0.22, 0.63),
        legend.key.size = unit(.4, 'cm')) +
  annotation_north_arrow(height = unit(.8, "cm"),
                         width = unit(.6, "cm"),
                         pad_x = unit(0.1, "in"), 
                         pad_y = unit(0.001, "in"),
                         style = north_arrow_minimal) +
  annotation_scale(style = "ticks",
                   pad_x = unit(0.4, "in"),
                   pad_y = unit(.15, "in"),
                   unit_category = "imperial",
                   width_hint = .2) -> map1

ggsave(map1,
       filename = "maps/eji_map.jpg")

#COVID DATA:
# Saving your data in shapefiles with the {sf} package 
ny_shp <- st_read("tract/tl_2024_36_tract.shp") %>%
  janitor:: clean_names() 
ny_shp <- ny_shp %>%  
  mutate(geoid = as.character(geoid)) 
#COVID dataset
modzcta_data <- read_csv("data-by-modzcta.csv") %>%
  janitor::clean_names() %>%
  mutate(modified_zcta = as.character(modified_zcta))
# Make sure both join columns are same type and name

covid_zcta <- left_join(modzcta_shapes, modzcta_data, by = c("MODZCTA" = "modified_zcta"))

#case rate:
rate_quant_breaks <- classIntervals(covid_zcta$covid_case_rate, n = 5, style = "quantile")$brks


ggplot() +
  geom_sf(data = covid_zcta,
          aes(fill = covid_case_rate),
          color = "black",
          linewidth = .2) +
  scale_fill_fermenter(direction = 1,
                       palette = "YlOrRd",
                       breaks = rate_quant_breaks) +
  labs(title = "COVID-19 Case Rate \nper 100k Residents",
       caption = "Author: Tobechi Dimkpa \n Source: NYC DOH",
       fill = "Rate") +
  theme_void() + 
  theme(plot.title = element_text(size = 13,
                                  family = "Avenir",
                                  vjust = -10,
                                  hjust = 0.10),
        plot.title.position = "plot",
        legend.title = element_text(size = 12),
        legend.position = c(0.22, 0.63),
        legend.key.size = unit(.4, 'cm')) +
  annotation_scale(pad_x = unit(1.4, "in"),
                   pad_y = unit(.3, "in"),
                   unit_category = "imperial") +
  annotation_north_arrow(location = "bl", which_north = "true", 
                         height = unit(.8, "cm"),
                         width = unit(1, "cm"),
                         pad_x = unit(1, "in"), 
                         pad_y = unit(0.2, "in"),
                         style = north_arrow_fancy_orienteering) -> map2
ggsave(map2,
       filename = "maps/covid_case_rate.jpg")

#Death rate:
death_quant_breaks <- classIntervals(covid_zcta$covid_death_rate, n = 5, style = "quantile")$brks
ggplot() +
  geom_sf(data = covid_zcta,
          aes(fill = covid_death_rate),
          color = "black",
          linewidth = .2) +
  scale_fill_fermenter(direction = 1,
                       palette = "YlOrRd",
                       breaks = death_quant_breaks) +
  labs(title = "COVID-19 Death Rate \nper 10k Residents",
       fill = "Rate") +
  theme_void() + 
  theme(plot.title = element_text(size = 13,
                                  family = "Avenir",
                                  vjust = -10,
                                  hjust = 0.10),
        plot.title.position = "plot",
        legend.title = element_text(size = 12),
        legend.position = c(0.22, 0.63),
        legend.key.size = unit(.4, 'cm')) +
  annotation_scale(pad_x = unit(1.4, "in"),
                   pad_y = unit(.3, "in"),
                   unit_category = "imperial") +
  annotation_north_arrow(location = "bl", which_north = "true", 
                         height = unit(.8, "cm"),
                         width = unit(1, "cm"),
                         pad_x = unit(1, "in"), 
                         pad_y = unit(0.2, "in"),
                         style = north_arrow_fancy_orienteering) -> map3
ggsave(map3,
       filename = "maps/covid_death_rate.jpg")

#Bivariate Analysis
#First join eji and covid data 
covid_eji <- left_join(modzcta_eji, modzcta_data, by = c("MODZCTA" = "modified_zcta"))
# Scatterplots with {ggplot2}
covid_eji |> 
  ggplot(aes(x = spl_ser, y = covid_case_rate)) +
  geom_point(color = "grey50",
             size = 0.8) +
  geom_smooth(method = "lm",
              color = "darkred",
              linetype = "dashed",
              linewidth = .4,
              se = FALSE) +
  theme_minimal() +
  labs(title = "Relationship between Environmental Justice Index and COVID-19 Case Rate",
       subtitle = "New York City, 2025 ",
       x = "EJI Percentile Rank",
       y = "Rate")

# Pearson's Correlation Coefficient 
cor.test(covid_eji$spl_ser, covid_eji$covid_case_rate, method = "pearson")
cor.test(covid_eji$spl_ser, covid_eji$covid_death_rate, method = "pearson")
#data:  covid_eji$spl_ser and covid_eji$covid_case_rate
t = -1.9447, df = 2764, p-value = 0.05191
alternative hypothesis: true correlation is not equal to 0
95 percent confidence interval:
  -0.0741323381  0.0003054471
sample estimates:
  cor 
-0.03696472 

# Calculate Spatial Lag  of EJI
covid_eji <- covid_eji |> 
  filter(!is.na(spl_ser))
covid_eji <- covid_eji |>
  mutate(nb = st_knn(geometry, 45),           # Identify neighbors
         wt = st_weights(nb, 
                         allow_zero = TRUE,           # Allow empty neighbor sets
                         style = "W"),                # Row standardized 
         eji_lag = st_lag(spl_ser, nb, wt))  # Calculate spatial lag

# Summary
summary(covid_eji$covid_case_rate)
summary(covid_eji$eji_lag)

# Base-map of case rates
ggplot() +
  geom_sf(data = covid_eji,
          aes(fill = covid_case_rate),
          color = NA) +
  scale_fill_viridis_c() +
  theme_void() 


# Base-map of lagged EJI
ggplot() +
  geom_sf(data = covid_eji,
          aes(fill = eji_lag),
          color = NA) +
  scale_fill_viridis_c() +
  theme_void() 

# Scatter plot 
# standardize X and Y
covid_eji <- covid_eji |>
  mutate(
    eji_std = (spl_ser - mean(spl_ser, na.rm = TRUE)) / sd(spl_ser, na.rm = TRUE),
    eji_lag_std = (eji_lag - mean(eji_lag, na.rm = TRUE)) / sd(eji_lag, na.rm = TRUE),
    case_std = (covid_case_rate - mean(covid_case_rate, na.rm = TRUE)) / sd(covid_case_rate, na.rm = TRUE))
ggplot(covid_eji, 
       aes(x = case_std, y = eji_lag_std)) +
  geom_point(alpha = .5) +
  geom_hline(yintercept = 0, color = "grey20", linetype = "dashed") + 
  geom_vline(xintercept = 0, color = "grey20", linetype = "dashed") +  
  geom_smooth(method = "lm", color = "red",  linewidth = 0.5, se = FALSE) +  # Regression line
  theme_minimal()

# Global Bivariate Morans i
global_moran_bv(covid_eji$covid_case_rate,
                covid_eji$eji_lag,
                covid_eji$nb,
                covid_eji$wt) -> bv_gmorans
print(bv_gmorans)

# Bivariate Morans I
covid_eji <- covid_eji |>
  mutate(biv_local_moran_I = local_moran_bv(covid_case_rate, spl_ser,
                                            nb, 
                                            wt, 
                                            nsim = 999)) |> 
  unnest(biv_local_moran_I)   

# Classify the clusters and filter by High-High and Low-Low
covid_eji |> 
  mutate(cluster_type = case_when(
    p_sim < 0.05 & case_std > 0 & eji_lag_std > 0 ~ "High-High",
    p_sim < 0.05 & case_std < 0 & eji_lag_std < 0 ~ "Low-Low",
    p_sim < 0.05 & case_std > 0 & eji_lag_std < 0 ~ "High-Low",
    p_sim < 0.05 & case_std < 0 & eji_lag_std > 0 ~ "Low-High",
    TRUE ~ "Not significant")) |> 
  filter(cluster_type %in% c("High-High", "Low-Low"))-> sel_clusters
NYC <- st_union(modzcta_shapes)
# Base Map
ggplot() +
  annotation_map_tile(type = "cartolight", zoomin = 0) +
  geom_sf(data = sel_clusters,
          aes(fill = cluster_type),
          alpha = 0.8,
          color = NA) +
  scale_fill_manual(values = c("#FF0000", "#0000FF")) + 
  geom_sf(data = NYC,
          color = "black",
          fill = NA) 

# Add final elements 
ggplot() +
  annotation_map_tile(type = "cartolight", zoomin = 0) +
  geom_sf(data = sel_clusters,
          aes(fill = cluster_type),
          alpha = 0.8,
          color = NA) +
  scale_fill_manual(values = c("#FF0000", "#0000FF")) + 
  geom_sf(data = NYC,
          color = "black",
          fill = NA) +
  labs(title = "Case Rate and EJI ",
       subtitle = "Significant Bivariate Local Moran's I, 
       2025",
       fill = "Clusters") +
  theme_void() +
  theme(plot.title = element_text(size = 13),
        plot.title.position = "plot",
        plot.subtitle = element_text(size = 11,
                                     face = "italic"),
        legend.position = "bottom",
        plot.caption = element_text(colour = "grey10",
                                    size = 8,
                                    vjust = 35,
                                    hjust = .95)) + 
  annotation_north_arrow(height = unit(.8, "cm"),
                         width = unit(.6, "cm"),
                         pad_x = unit(0.6, "in"), 
                         pad_y = unit(0, "in"),
                         style = north_arrow_minimal) +
  annotation_scale(style = "ticks",
                   pad_x = unit(1, "in"),
                   pad_y = unit(.05, "in"),
                   unit_category = "imperial",
                   width_hint = .2) -> map4

# Export cluster map
ggsave(map4,
       filename = "maps/bi_cluster_caserate.jpg",
       width = 6,
       height = 6)

#Death rate
# Scatter plot 
# standardize X and Y
covid_eji <- covid_eji |>
  mutate(
    death_std = (covid_death_rate - mean(covid_death_rate, na.rm = TRUE)) / sd(covid_death_rate, na.rm = TRUE))
ggplot(covid_eji, 
       aes(x = death_std, y = eji_lag_std)) +
  geom_point(alpha = .5) +
  geom_hline(yintercept = 0, color = "grey20", linetype = "dashed") + 
  geom_vline(xintercept = 0, color = "grey20", linetype = "dashed") +  
  geom_smooth(method = "lm", color = "red",  linewidth = 0.5, se = FALSE) +  # Regression line
  theme_minimal()

# Global Bivariate Morans i
global_moran_bv(covid_eji$covid_death_rate,
                covid_eji$eji_lag,
                covid_eji$nb,
                covid_eji$wt) -> bv_gmorans2
print(bv_gmorans2)

# Bivariate Morans I
covid_eji <- covid_eji |>
  mutate(biv_local_moran_I2 = local_moran_bv(covid_death_rate, spl_ser,
                                            nb, 
                                            wt, 
                                            nsim = 999)) |> 
  unnest(biv_local_moran_I2, names_sep = "_")   

# Classify the clusters and filter by High-High and Low-Low
covid_eji |> 
  mutate(cluster_type2 = case_when(
    p_sim < 0.05 & death_std > 0 & eji_lag_std > 0 ~ "High-High",
    p_sim < 0.05 & death_std < 0 & eji_lag_std < 0 ~ "Low-Low",
    p_sim < 0.05 & death_std > 0 & eji_lag_std < 0 ~ "High-Low",
    p_sim < 0.05 & death_std < 0 & eji_lag_std > 0 ~ "Low-High",
    TRUE ~ "Not significant")) |> 
  filter(cluster_type2 %in% c("High-High", "Low-Low"))-> sel_clusters2

# Base Map
ggplot() +
  annotation_map_tile(type = "cartolight", zoomin = 0) +
  geom_sf(data = sel_clusters2,
          aes(fill = cluster_type2),
          alpha = 0.8,
          color = NA) +
  scale_fill_manual(values = c("#FF0000", "#0000FF")) + 
  geom_sf(data = NYC,
          color = "black",
          fill = NA) 

# Add final elements 
ggplot() +
  annotation_map_tile(type = "cartolight", zoomin = 0) +
  geom_sf(data = sel_clusters2,
          aes(fill = cluster_type2),
          alpha = 0.8,
          color = NA) +
  scale_fill_manual(values = c("#FF0000", "#0000FF")) + 
  geom_sf(data = NYC,
          color = "black",
          fill = NA) +
  labs(title = " COVID-19 Death Rate and EJI",
       subtitle = "Significant Bivariate Local Moran's I, 
       2025",
       fill = "Clusters") +
  theme_void() +
  theme(plot.title = element_text(size = 13),
        plot.title.position = "plot",
        plot.subtitle = element_text(size = 11,
                                     face = "italic"),
        legend.position = "bottom",
        plot.caption = element_text(colour = "grey10",
                                    size = 8,
                                    vjust = 35,
                                    hjust = .95)) + 
  annotation_north_arrow(height = unit(.8, "cm"),
                         width = unit(.6, "cm"),
                         pad_x = unit(0.6, "in"), 
                         pad_y = unit(0, "in"),
                         style = north_arrow_minimal) +
  annotation_scale(style = "ticks",
                   pad_x = unit(1, "in"),
                   pad_y = unit(.05, "in"),
                   unit_category = "imperial",
                   width_hint = .2) -> map5

# Export cluster map
ggsave(map5,
       filename = "maps/bi_cluster_deathrate.jpg",
       width = 6,
       height = 6)
combined <- (map1 | map2 | map3) / (map4 | map5)
wrap_plots(map2, map3)
map4 / map5

(map4 + map5) +
  plot_layout(guides = "collect") +
  plot_annotation(
    title = "Spatial Clusters of COVID-19 Case and Death Rates with EJI: NYC",
    caption = "Author: Tobechi Dimkpa \n Source: NYC DOH"
  ) &
  theme(legend.position = "bottom")

wrap_plots(
  map2 + plot_spacer() +map3,
  map1,
  ncol = 1,
  heights = c(1, 1.2)  # Adjust heights as needed
) 
# Calculate Moran’s I for EJI values
moran_result <- covid_eji |>
  mutate(nb = st_knn(geometry, k = 45),
         wt = st_weights(nb, style = "W")) |>
  moran_test(spl_ser, nb, wt)

print(moran_result)

