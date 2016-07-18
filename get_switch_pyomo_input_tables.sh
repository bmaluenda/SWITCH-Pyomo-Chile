#!/bin/bash

# Date of creation: Spring 2016

# SWITCH-Chile!

# Note about the authors: This file was modified by B Maluenda from get_switch_input_tables.sh written by JP Carvallo and P Hidalgo.

start_time=$(date +%s)

function print_help {
  echo $0 # Print the name of this file. 
  # Print the following text, end at the phrase END_HELP
  cat <<END_HELP
SYNOPSIS
	./get_switch_input_tables.sh 
DESCRIPTION
	Pull input data for Switch from a database and format it for Pyomo
This script assumes that the input database has already been built.

INPUTS
 --help                   Print this message
 -u [DB Username]
 -D [DB name]
 -h [DB server]
 -w
All arguments are optional.
END_HELP
}

# Export SWITCH input data from the Switch inputs database into tab files that will be read in by Pyomo

write_to_path='inputs'
db_server="switch-db2.erg.berkeley.edu"
DB_name="switch_gis"

###################################################
# Detect optional command-line arguments
help=0
while [ -n "$1" ]; do
case $1 in
  -u)
    user=$2; shift 2 ;;
  -D)
    DB_name=$2; shift 2 ;;
  -h)
    db_server=$2; shift 2 ;;
  --help)
		print_help; exit ;;
  *)
    echo "Unknown option $1"
		print_help; exit ;;
esac
done

##########################
# Get the user name (default to system user name of current user) 

#I commented this line, since my system username (Benjamin) is different than my server username (bmaluenda)
#default_user=$(whoami)
#This 2 lines are just to go around the if statement.
default_user="bmaluenda"
user="bmaluenda"

if [ ! -n "$user" ]
then 
	printf "User name for PostGreSQL $DB_name on $db_server [$default_user]? "
	read user
	if [ -z "$user" ]; then 
	  user="$default_user"
	fi
fi

#The commented line creates the string from the user's input.
#I went around it and wrote my own string to save time.
#connection_string="psql -h $db_server -U $user $DB_name"
connection_string="psql -h 127.0.0.1 -p 5433 -U bmaluenda -d switch_chile"

test_connection=`$connection_string -t -c "select count(*) from chile_new.scenarios_switch_chile;"`

if [ ! -n "$test_connection" ]
then
	connection_string=`echo "$connection_string" | sed -e "s/ -p[^ ]* / -pXXX /"`
	echo "Could not connect to database with settings: $connection_string"
	exit 0
fi

############################################################################################################
# These next variables determine which input data is used, though some are only for documentation and result exports.

# The simulated scenario is defined by the IDs in the scenarios_switch_chile Table in the DB.
read SCENARIO_ID < scenario_id.txt
# Make sure this scenario id is valid.
if [ $($connection_string -t -c "select count(*) from chile_new.scenarios_switch_chile where scenario_id=$SCENARIO_ID;") -eq 0 ]; then 
	echo "ERROR! This scenario id ($SCENARIO_ID) is not in the database. Exiting."
	exit 1;
fi

SCENARIO_NAME=$($connection_string -t -c "select scenario_name from chile_new.scenarios_switch_chile where scenario_id = $SCENARIO_ID;")
SCENARIO_NOTES=$($connection_string -t -c "select scenario_notes from chile_new.scenarios_switch_chile where scenario_id = $SCENARIO_ID;")

# HYD_ID is used to choose an inflow hydrological window. Windows are 18 years long and externally built in the DB.
# HYD_ID 1 is the interval 1960-1977 and HYD_ID 33 is 1992-2009.
export HYD_ID=$($connection_string -t -c "select hyd_id from chile_new.scenarios_switch_chile where scenario_id = $SCENARIO_ID;")

# Variable not used in model, only for documentation of the run.
#export FROM_YEAR=$($connection_string -t -c "select from_year from chile_new.hydrological_window_reservoir_2 where hyd_id = $HYD_ID;")

# The CARBON CAP ID will take a value of '0' if no Carbon Cap is active. Otherwise, the Carbon Cap module is loaded and the constraint is enforced.
export CARBON_CAP_ID=$($connection_string -t -c "select carbon_cap_id from chile_new.scenarios_switch_chile where scenario_id = $SCENARIO_ID;")

# The CARBON TAX ID will take a value of '0' if no Carbon Tax is active. Otherwise, the Carbon Tax module is loaded and the constraint is enforced.
export CARBON_TAX_ID=$($connection_string -t -c "select carbon_tax_id from chile_new.scenarios_switch_chile where scenario_id = $SCENARIO_ID;")

# The RPS ID will take a value of '0' if no RPS is active. Otherwise, the RPS module is loaded and the constraint is enforced.
export RPS_ID=$($connection_string -t -c "select rps_id from chile_new.scenarios_switch_chile where scenario_id = $SCENARIO_ID;")

export FUEL_COST_ID=$($connection_string -t -c "select fuel_cost_id from chile_new.scenarios_switch_chile where scenario_id = $SCENARIO_ID;")

export OVERNIGHT_COST_ID=$($connection_string -t -c "select overnight_cost_id from chile_new.scenarios_switch_chile where scenario_id = $SCENARIO_ID;")

export NEW_PROJECT_PORTFOLIO_ID=$($connection_string -t -c "select new_project_portfolio_id from chile_new.scenarios_switch_chile where scenario_id = $SCENARIO_ID;")

export DEMAND_SCENARIO_ID=$($connection_string -t -c "select demand_scenario_id from chile_new.scenarios_switch_chile where scenario_id = $SCENARIO_ID;")

export TIMESCALES_SET_ID=$($connection_string -t -c "select timescales_set_id from chile_new.scenarios_switch_chile where scenario_id = $SCENARIO_ID;")

TIMESCALES_SET_NOTES=$($connection_string -t -c "select timescales_set_notes from chile_new.timescales_sets where timescales_set_id = $TIMESCALES_SET_ID;")

export STUDY_START_YEAR=$($connection_string -t -c "select study_start_year from chile_new.timescales_sets where timescales_set_id=$TIMESCALES_SET_ID;")

number_of_timepoints=$($connection_string -t -c "select number_of_timepoints from chile_new.timescales_sets where timescales_set_id=$TIMESCALES_SET_ID;")

number_of_periods=$($connection_string -t -c "select number_of_periods from chile_new.timescales_sets where timescales_set_id=$TIMESCALES_SET_ID;")

# get the present year that will make present day cost optimization possible
present_year=$($connection_string -t -c "select 2011;")


############################################################################################################################################
# File writing begins in the inputs directory. 
if [ ! -d $write_to_path ]; then
  mkdir $write_to_path
  echo "Inputs directory created"
else
  rm -r $write_to_path/*
  echo "Input directory already existed, so contents have been erased"
fi

cd  $write_to_path

#First, scenario documentation is written in the scenario_params.dat file.

echo 'Writing scenario ids to scenario_params_doc.txt for documentation'
echo "Scenario ID: $SCENARIO_ID" >>  scenario_params_doc.txt
echo "Scenario name: $SCENARIO_NAME" >>  scenario_params_doc.txt
echo "Scenario notes: $SCENARIO_NOTES" >>  scenario_params_doc.txt
echo "Hydrological window ID: $HYD_ID" >>  scenario_params_doc.txt
echo "Hydrology from year: $FROM_YEAR" >>  scenario_params_doc.txt
echo "RPS ID: $RPS_ID"  >> scenario_params_doc.txt
echo "Carbon cap ID: $CARBON_CAP_ID" >>  scenario_params_doc.txt
echo "Carbon tax ID: $CARBON_TAX_ID" >>  scenario_params_doc.txt
echo "Fuel costs ID: $FUEL_COST_ID"  >> scenario_params_doc.txt
echo "New project portfolio ID: $NEW_PROJECT_PORTFOLIO_ID"  >> scenario_params_doc.txt
echo "Timescales set ID: $TIMESCALES_SET_ID"  >> scenario_params_doc.txt
echo "Timescales set notes:$TIMESCALES_SET_NOTES"  >> scenario_params_doc.txt
echo "Demand scenario ID: $DEMAND_SCENARIO_ID"  >> scenario_params_doc.txt
echo "Number of timepoints: $number_of_timepoints"  >> scenario_params_doc.txt
echo "Number of periods: $number_of_periods"  >> scenario_params_doc.txt
echo "Study start year: $STUDY_START_YEAR"  >> scenario_params_doc.txt
echo "Present year for discounted costs: $present_year"  >> scenario_params_doc.txt

echo 'Writing required modules for simulation'
echo 'project.no_commit' >> modules
echo 'fuel_cost' >> modules
echo 'trans_build' >> modules
echo 'trans_dispatch' >> modules
echo 'Chile.exporting' >> modules
if [ $RPS_ID -ne 0 ]; then echo 'Chile.RPS' >> modules; fi
if [ $CARBON_CAP_ID != 0 ]; then echo 'Chile.carbon_cap' >> modules; fi
if [ $CARBON_TAX_ID != 0 ]; then echo 'Chile.carbon_tax' >> modules; fi

# The format for tab files is:
# col1_name col2_name ...
# [rows of data]

# The format for dat files is the same as in AMPL dat files.

echo $'\nStarting data copying from the database to input files\n'

########################################################
# TIMESCALES

# Periods are the investment time scale. Their name can be any string. Periods need not be the same length.
echo '	periods.tab...'
echo -e 'INVESTMENT_PERIOD\tperiod_start\tperiod_end' >> periods.tab
$connection_string -A -t -F  $'\t' -c "SELECT period_name, \
period_start, period_end \
FROM chile_new.timescales_set_periods \
WHERE timescales_set_id=$TIMESCALES_SET_ID ORDER BY 1;" >> periods.tab

# Timeseries are a new feature in Pyomo, which is more flexible than the "date" index in AMPL.
# Each timeserie is a grouping of timepoints. Its name can be any string. Timepoint distribution inside 
# a timeserie must be uniform. Timeseries are used for unit commitment (makes timepoints circular).
echo '	timeseries.tab...'
echo -e 'TIMESERIES\tts_period\tts_duration_of_tp\tts_num_tps\tts_scale_to_period' >> timeseries.tab
$connection_string -A -t -F  $'\t' -c "SELECT timeseries_name, period_name, duration_of_tps,\
num_tps, scale_to_period
FROM  chile_new.timescales_set_timeseries
WHERE (timescales_set_id = $TIMESCALES_SET_ID) ORDER BY 2, 1;" >> timeseries.tab

# Timepoint IDs can be any string. I use timestamps in a string format to make it easier to interpret results manually.
# Timestamp is taken to be the "hour number", a serial from the DB.
echo '	timepoints.tab...'
echo 'timepoint_id	timestamp	timeseries' >> timepoints.tab
$connection_string -A -t -F  $'\t' -c "SELECT to_char(timestamp_cst, 'YYYYMMDDHH24'), \
hour_number, timeseries_name
FROM  chile_new.timescales_set_timepoints
WHERE timescales_set_id = $TIMESCALES_SET_ID ORDER BY 2;" >> timepoints.tab

########################################################
# LOAD ZONES AND BALANCING AREAS

# lz_cost_multipliers are used in ONC, variable O&M and fixed O&M to multiply the generic generation costs. 
# If project values are inputted for these costs, they are not necesary.
# Cost multipliers and distance to carbon sinks are forced to be '.'.
# Existing T&D is assumed to be just enough to cover the peak demand in the period (the peak of the middle year)
# plus the planning reserves (which default to 0.15 in the Chile.capacity_reserves module). I won't be using
# the local_td module, so these values are just placeholders if in the future someone uses it.
echo '	load_zones.tab...'
echo -e 'LOAD_ZONE\tlz_cost_multipliers\tlz_ccs_distance_km\tlz_dbid\texisting_local_td\tlocal_td_annual_cost_per_mw' >>load_zones.tab
$connection_string -A -t -F  $'\t' -c  "SELECT ALL lz_name, '.', '.', lz_dbid, existing_local_td, local_td_annual_cost_per_mw
FROM chile_new.load_zones
ORDER BY 1;" >> load_zones.tab

# Loads are specified according to the demand scenario selected (demand projection).
echo '	loads.tab...'
echo -e 'LOAD_ZONE\tTIMEPOINT\tlz_demand_mw' >> loads.tab
$connection_string -A -t -F  $'\t' -c  "SELECT lz_name, TO_CHAR(timestamp_cst, 'YYYYMMDDHH24'), lz_demand_mwh 
FROM chile_new.lz_hourly_demand_2060
JOIN chile_new.timescales_set_timepoints USING (timestamp_cst)
WHERE demand_scenario_id = $DEMAND_SCENARIO_ID
AND timescales_set_id = $TIMESCALES_SET_ID
ORDER BY 1,2;" >> loads.tab

# Balancing areas define groups of load zones where reserve requirements are calculated and enforced. No operating reserves
# module has been written yet, so this inputs are not used anywhere and are just placeholders.
echo '	balancing_areas.tab...'
echo -e 'BALANCING_AREAS\tquickstart_res_load_frac\tquickstart_res_wind_frac\tquickstart_res_solar_frac\tspinning_res_load_frac\tspinning_res_wind_frac\tspinning_res_solar_frac' >> balancing_areas.tab
$connection_string -A -t -F  $'\t' -c  "SELECT balancing_area,\
quickstart_res_load_frac, quickstart_res_wind_frac, quickstart_res_solar_frac, \
spinning_res_load_frac, spinning_res_wind_frac, spinning_res_solar_frac
FROM chile_new.balancing_areas;" >> balancing_areas.tab

echo '	lz_balancing_areas.tab...'
echo -e 'LOAD_ZONE\tbalancing_area'>>lz_balancing_areas.tab
$connection_string -A -t -F  $'\t' -c "SELECT lz_name, balancing_area
FROM chile_new.load_zones;">>lz_balancing_areas.tab

# Peak demand is calculated as the maximum demand in the middle year of the period. 
# This is a reasonable approximation considering that if left unconstrained, this will always find a max 
# near the next period (usually the last year on the current period), considering positive demand growth. 
# If smaller periods are used, this constraint could be relaxed and the true maximum found.
echo '	lz_peak_loads.tab'
echo -e 'LOAD_ZONE\tPERIOD\tpeak_demand_mw' >> lz_peak_loads.tab
$connection_string -A -t -F  $'\t' -c  "SELECT lzhd.lz_name, period_name, max(lz_demand_mwh)
FROM chile_new.lz_hourly_demand_2060 lzhd
	JOIN chile_new.scenarios_switch_chile USING (demand_scenario_id)
    JOIN chile_new.timescales_set_periods USING (timescales_set_id)  
	JOIN chile_new.hours_2060 USING (timestamp_cst)  
	JOIN chile_new.load_zones USING (lz_dbid) 
  WHERE timescales_set_id = $TIMESCALES_SET_ID  
	AND demand_scenario_id = $DEMAND_SCENARIO_ID 
    AND year = FLOOR( period_start + (period_end - period_start + 1) / 2 ) 
  GROUP BY lzhd.lz_name, period_name
  ORDER BY 1,2;">>lz_peak_loads.tab 

########################################################
# TRANSMISSION

# Tx lines must only be specified in one direction (doesn't matter which).
echo '	transmission_lines.tab...'
echo -e 'TRANSMISSION_LINE\ttrans_lz1\ttrans_lz2\ttrans_length_km\ttrans_efficiency\texisting_trans_cap' >>transmission_lines.tab
$connection_string -A -t -F  $'\t' -c  "SELECT transmission_line_id, \
lz1, lz2, trans_length_km, trans_efficiency, existing_trans_cap_mw
FROM chile_new.transmission_lines
ORDER BY 2,3;">>transmission_lines.tab	

# Derating factors and terrain multipliers for Chile have not yet been included.
echo '	trans_optional_params.tab...'
echo -e 'TRANSMISSION_LINE\ttrans_dbid\ttrans_derating_factor\ttrans_terrain_multiplier\ttrans_new_build_allowed' >>trans_optional_params.tab
$connection_string -A -t -F  $'\t' -c  "SELECT transmission_line_id, transmission_line_id, '.', '.', new_build_allowed
FROM chile_new.transmission_lines
ORDER BY 1;">>trans_optional_params.tab	

#All the following params are taken from the AMPL model and don't change between simulations. Should be updated and revised.
echo '	trans_params.dat...'
echo 'param trans_capital_cost_per_mw_km:=1000;'>>trans_params.dat
echo 'param trans_lifetime_yrs:=20;'>>trans_params.dat
echo 'param trans_fixed_o_m_fraction:=0.03;'>>trans_params.dat
echo 'param distribution_loss_rate:=0.0652;'>>trans_params.dat

########################################################
# FUEL

echo '	fuels.tab...'
echo -e 'fuel\tco2_intensity\tupstream_co2_intensity' >> fuels.tab
$connection_string -A -t -F  $'\t' -c  "SELECT energy_source, co2_intensity, upstream_co2_intensity
carbon_content_without_carbon_accounting, 0
FROM chile_new.fuels
WHERE fuel IS TRUE;" >> fuels.tab

echo '	non_fuel_energy_sources.tab...'
echo 'energy_source' >> non_fuel_energy_sources.tab
$connection_string -A -t -F  $'\t' -c  "SELECT energy_source
FROM chile_new.fuels
WHERE non_fuel_energy_source IS TRUE;">> non_fuel_energy_sources.tab

# Fuel projections are yearly averages in the DB. For now, Switch only accepts fuel prices per period, so they are averaged.
echo '	fuel_cost.tab'
echo -e 'load_zone\tfuel\tperiod\tfuel_cost' >> fuel_cost.tab
$connection_string -A -t -F  $'\t' -c  "SELECT lz_name, fuel, period_name, ROUND( AVG(fuel_price) , 4)
FROM chile_new.fuel_yearly_prices
CROSS JOIN chile_new.timescales_set_periods
WHERE fuel_cost_id = $FUEL_COST_ID AND timescales_set_id = $TIMESCALES_SET_ID 
AND projection_year BETWEEN period_start AND period_end
GROUP BY lz_name, fuel, period_name 
ORDER BY 1, 2, 3;" >> fuel_cost.tab

########################################################
# GENERATOR TECHNOLOGIES

# Care must be exercised when defining parameters that do not apply to all technologies, 
# such as heat rate (i.e. heat rate means nothing to solar PV technologies). 
# Values of 0 are used in the DB to indicate optional parameters (or if no info is available). This cases are written out as '.' dots.
# I haven't found a more clever way to write optional parameters in the DB.
echo '	generator_info.tab'
echo -e 'generation_technology\tg_max_age\tg_is_variable\tg_is_baseload\tg_is_flexible_baseload\tg_is_cogen\tg_competes_for_space\tg_variable_o_m\tg_energy_source\tg_dbid\tg_scheduled_outage_rate\tg_forced_outage_rate\tg_min_build_capacity\tg_full_load_heat_rate\tg_unit_size' >> generator_info.tab
$connection_string -A -t -F  $'\t' -c  "SELECT technology_name, max_age, \
CASE WHEN variable THEN 1 ELSE 0 END, CASE WHEN baseload THEN 1 ELSE 0 END, \
CASE WHEN flexible_baseload THEN 1 ELSE 0 END, CASE WHEN cogen THEN 1 ELSE 0 END, \
CASE WHEN competes_for_space THEN 1 ELSE 0 END, variable_o_m, \
energy_source, technology_id, scheduled_outage_rate, forced_outage_rate, \
CASE WHEN min_build_capacity IS NULL THEN '.' ELSE TO_CHAR(min_build_capacity::real,'9D999') END, \
CASE WHEN full_load_heat_rate IS NULL THEN '.' ELSE TO_CHAR(full_load_heat_rate::real,'9D999') END, \
CASE WHEN unit_size IS NULL THEN '.' ELSE TO_CHAR(unit_size::real,'9D999') END
FROM chile_new.generator_info
ORDER BY 1;" >> generator_info.tab

# Yearly overnight and fixed o&m cost projections are averaged for each study period.
echo '	gen_new_build_costs.tab...'
echo -e 'generation_technology\tinvestment_period\tg_overnight_cost\tg_fixed_o_m' >> gen_new_build_costs.tab
$connection_string -A -t -F  $'\t' -c  "SELECT technology_name, \
period_name, ROUND(AVG(overnight_cost),2), ROUND(AVG(fixed_o_m),2)
FROM chile_new.generator_yearly_costs
CROSS JOIN chile_new.timescales_set_periods
WHERE overnight_cost_id = $OVERNIGHT_COST_ID AND timescales_set_id = $TIMESCALES_SET_ID 
AND projection_year BETWEEN period_start AND period_end
GROUP BY 1,2
ORDER BY 1,2;" >> gen_new_build_costs.tab


########################################################
# PROJECTS

# I kept the separation of existing and new projects from the Chile DB in the new one.
# Helps the maintenance of the tables and readability, though they contain the same parameters, except for the start_year and capacity_mw of the existing projects.
echo '	project_info.tab...'
echo -e 'PROJECT\tproj_gen_tech\tproj_load_zone\tproj_connect_cost_per_mw\tproj_variable_om\tproj_full_load_heat_rate\tproj_forced_outage_rate\tproj_scheduled_outage_rate\tproj_dbid\tproj_capacity_limit_mw' >> project_info.tab
$connection_string -A -t -F  $'\t' -c  "SELECT project_name, \
gen_tech, load_zone, connect_cost_per_mw, variable_o_m, \
CASE WHEN full_load_heat_rate IS NULL THEN '.' ELSE TO_CHAR(full_load_heat_rate::real,'9D999') END, \
CASE WHEN forced_outage_rate IS NULL THEN '.' ELSE TO_CHAR(forced_outage_rate::real,'9D999') END, \
CASE WHEN scheduled_outage_rate IS NULL THEN '.' ELSE TO_CHAR(scheduled_outage_rate::real,'9D999') END, \
project_id, capacity_limit_mw
FROM chile_new.project_info_existing
UNION
SELECT project_name, \
gen_tech, load_zone, connect_cost_per_mw, variable_o_m, \
CASE WHEN full_load_heat_rate IS NULL THEN '.' ELSE TO_CHAR(full_load_heat_rate::real,'9D999') END, \
CASE WHEN forced_outage_rate IS NULL THEN '.' ELSE TO_CHAR(forced_outage_rate::real,'9D999') END, \
CASE WHEN scheduled_outage_rate IS NULL THEN '.' ELSE TO_CHAR(scheduled_outage_rate::real,'9D999') END, \
project_id, capacity_limit_mw
FROM chile_new.project_info_new
JOIN chile_new.new_projects_scenarios USING (project_id)
WHERE new_project_portfolio_id = $NEW_PROJECT_PORTFOLIO_ID
ORDER BY 2,3;">> project_info.tab

#Projects SING2, SING3, SING4 and SING5 are RoR plants in the northern system, for which there is no available hydro info in the DB, so they are excluded.

echo '	proj_existing_builds.tab...'
echo -e 'PROJECT\tbuild_year\tproj_existing_cap' >> proj_existing_builds.tab
$connection_string -A -t -F  $'\t' -c  "SELECT project_name, \
start_year, capacity_mw
FROM chile_new.project_info_existing;">> proj_existing_builds.tab

# Question: Can ON and FO&M costs not be provided for existing projects? Will those values default to their technology?
echo '	proj_build_costs.tab...'
echo -e 'PROJECT\tbuild_year\tproj_overnight_cost\tproj_fixed_om' >> proj_build_costs.tab
$connection_string -A -t -F  $'\t' -c  "SELECT project_name, \
start_year, CASE WHEN overnight_cost IS NULL THEN '.' ELSE TO_CHAR(overnight_cost::real,'9999999D9') END, \
CASE WHEN fixed_o_m IS NULL THEN '.' ELSE TO_CHAR(fixed_o_m::real,'999999D9') END
FROM chile_new.project_info_existing;" >> proj_build_costs.tab

########################################################
# FINANCIALS

echo '	financials.dat...'
echo 'param base_financial_year := 2014;'>>financials.dat
echo 'param interest_rate := .07;'>>financials.dat
echo 'param discount_rate := .07;'>>financials.dat

########################################################
# VARIABLE CAPACITY FACTORS

#This convolusion of JOINS must be implemented because intermittent capacity factors are only defined until a certain year (I don't know which one). So, 2014 values are repeated yearly and timepoints are matched by hour and month.

#A UNION must be implemented to stitch together capacity factors from new and existing plants that are not hydro

#The second UNION incorporates the capacity factors from new

#Pyomo will raise an error if a capacity factor is defined for a project on a timepoint when it is no longer operational (i.e. Canela 1 was built on 2007 and has a 30 year max age, so for tp's ocurring later than 2037, its capacity factor must not be written in the table). 
echo '	variable_capacity_factors.tab... inserting non-RoR'
echo -e 'PROJECT\ttimepoint\tproj_max_capacity_factor' >>variable_capacity_factors.tab
$connection_string -A -t -F  $'\t' -c  "
SELECT project_name, TO_CHAR(t1.timestamp_cst, 'YYYYMMDDHH24'), TO_CHAR(t2.timestamp_cst, 'YYYYMMDDHH24'),\
CASE WHEN capacity_factor>1.999 THEN 1.999 ELSE capacity_factor END
FROM(	SELECT project_id, timestamp_cst, hour_of_year, capacity_factor
		FROM chile_new.variable_capacity_factors_new
		JOIN chile_new.hours_2060 USING (timestamp_cst)
		WHERE year = 2014 ) t1
JOIN (SELECT hour_of_year, timestamp_cst 
		FROM chile_new.timescales_set_timepoints
		JOIN chile_new.hours_2060 USING (timestamp_cst)
		WHERE timescales_set_id = $TIMESCALES_SET_ID ) t2 USING (hour_of_year)
JOIN chile_new.project_info_new USING (project_id)
JOIN chile_new.new_projects_scenarios USING (project_id)
WHERE new_project_portfolio_id = $NEW_PROJECT_PORTFOLIO_ID;" >> variable_capacity_factors.tab
exit 1
UNION
SELECT project_name, TO_CHAR(t1.timestamp_cst, 'YYYYMMDDHH24'), capacity_factor
	FROM(
		SELECT project_id, la_id, month_of_year, hour_of_year, hour_of_day, capacity_factor
		FROM chile_new.existing_plant_intermittent_capacity_factor
		JOIN chile_new.hours_2060 h using (hour_number, hour_of_year)
		WHERE year = 2014 ) t1
	JOIN chile_new.existing_plants_wo_hydro using (project_id, la_id)
	JOIN (SELECT distinct year, t.hour_of_year, t.timestamp_cst, hour_number
		FROM chile_new.timescales_set_timepoints t
		JOIN chile_new.hours_2060 USING (hour_number)
		WHERE timescales_set_id = $timescales_SET_ID ORDER BY 1,2) t3 USING (hour_of_year)
WHERE technology <> 'Hydro_NonPumped' 
ORDER BY 1, 2;">> variable_capacity_factors.tab
 
#AND project_id in ('SIC70','SIC71','SIC72','SIC73','SIC74','SIC17','SIC32','SIC42','SIC48','SIC49','SIC53')
  
#Note from JP and Paty: The file is made in two steps: First, add the RoR cap factors averaged through the period. Second, directly sample the remaining intermittent cap factors.
# Note that I exclude technology_id 118 (New RoR) instead of 121 (EP RoR) because of an error in the initial assignment. This doesn't affect the loading of data because the technology_id is not loaded, but the name (technology)

echo '	variable_capacity_factors.tab... inserting RoR'

$connection_string -A -t -F  $'\t' -c "drop table if exists temp_hydro_ror_ep_adjustment_factors;"

#Creation of temporary table with capacity factors (UNTOUCHED)
$connection_string -A -t -F  $'\t' -c "select project_id, avg_proj_yr as projection_year, month_of_year, avg(adj_factor) as avg_adj_factor \
into temp_hydro_ror_ep_adjustment_factors \
from( \
select project_id, projection_year, \
CASE WHEN projection_year >= period_start and projection_year <= period_end THEN period_start END as avg_proj_yr, \
month as month_of_year, adj_factor \
from chile_new.hydro_limits_ep_hydrologies \
join chile_new.hydro_limits_ep_random_series using (n) \
join \
(select project_id, year, month, adj_factor \
from \
( \
select project_id, hydro_year, tstampyear as year, month, \
CASE WHEN avg_capacity_factor = 0 THEN 1 ELSE escalated_cap_fact/avg_capacity_factor END as adj_factor \
from chile_new.escalated_historic_cap_fact_final_2 \
join (select * from chile_new.existing_plant_intermittent_capacity_factor_monthly where year = 2014) t1 using (project_id, month) \
order by 1,3,4 \
) t4 \
where year > 1960 \
order by 1,2,3) t1 using (year), \
(select period_start, period_end \
from chile_new.timescales_set_periods \
where timescales_set_id = $timescales_SET_ID \
order by 1) t3 \
where n = $HYD_ID and projection_year >= period_start and projection_year <= period_end \
order by 1,2,4) t2 \
group by 1,2,3 order by 1,2,3;"
 
#Capacity factors from the temorary table are inserted into the tab file
$connection_string -A -t -F  $'\t' -c "SELECT plant_name, tps.hour_number, CASE WHEN AVG(capacity_factor * avg_adj_factor) > 1.4 THEN 1.4 ELSE AVG(capacity_factor * avg_adj_factor) END
FROM (
	SELECT project_id, la_id, hour_of_year, month_of_year, capacity_factor, hour_number
	FROM chile_new.existing_plant_intermittent_capacity_factor
	JOIN chile_new.hours_2060 h USING (hour_number, hour_of_year)
		WHERE year = 2014 ) t1
JOIN chile_new.existing_plants_wo_hydro USING (project_id, la_id)
JOIN (SELECT DISTINCT period as projection_year, t.hour_of_year
	FROM chile_new.timescales_set_timepoints t
	WHERE timescales_set_id = $timescales_SET_ID order by 1,2) t3
	USING (hour_of_year)
JOIN chile_new.temp_hydro_ror_ep_adjustment_factors 
	USING (project_id, projection_year, month_of_year)
JOIN chile_new.timescales_set_timepoints tps ON tps.hour_of_year = t3.hour_of_year AND tps.timescales_set_id = $timescales_SET_ID
WHERE technology <> 'Hydro_NonPumped' AND project_id NOT IN ('SIC70','SIC71','SIC72','SIC73','SIC74','SIC17','SIC32','SIC42','SIC48','SIC49','SIC53')
GROUP BY plant_name, tps.hour_number
ORDER BY 1,2;" >> variable_capacity_factors.tab

#I add placeholders for Hydro_NonPumped and Hydro_NonPumped_New generators, because no capacity factor data is available for them, but Pyomo needs the input to exist.

$connection_string -A -t -F  $'\t' -c "SELECT plant_name, \
hour_number, '0.01'
FROM chile_new.existing_plants_wo_hydro
CROSS JOIN chile_new.timescales_set_timepoints 
WHERE technology = 'Hydro_NonPumped' AND timescales_set_id = $timescales_SET_ID
ORDER BY 1,2 ;" >> variable_capacity_factors.tab

$connection_string -A -t -F  $'\t' -c "SELECT TO_CHAR(project_id, '999'), hour_number, '0.01'
FROM chile_new.new_projects_v4 np
CROSS JOIN chile_new.timescales_set_timepoints
JOIN chile_new.new_projects_scenarios USING (project_id) 
WHERE technology = 'Hydro_NonPumped_New' AND timescales_set_id = $timescales_SET_ID AND new_project_portfolio_id=$NEW_PROJECT_PORTFOLIO_ID 
ORDER BY 1,2 ;" >> variable_capacity_factors.tab

cd ..

end_time=$(date +%s)

echo $'\nProcess finished. Creation of input files took '$((end_time-start_time))' seconds.'

exit 1

#The following is code for building some hydro limits tables used in AMPL.

# Paty: importing hydro_monthly_limits with hydro_window. For now it will be separated 
# between RoR and Reservoirs. The work is done and ready for Reservoirs, that's why
# this division needs to be made for now.
# JP: Splitting the hydro monthly limits in two, so they can be handled separately in switch.mod
#     The EP version has hydro variability in it
echo '	hydro_monthly_limits_ep.tab...'
echo ampl.tab 4 1 > hydro_monthly_limits_ep.tab
echo 'project_id	la_id	technology	date	average_output_mw' >> hydro_monthly_limits_ep.tab

#$connection_string -A -t -F  $'\t' -c  " DROP TABLE IF EXISTS temp7_hydro_study_dates_export;"

$connection_string -A -t -F  $'\t' -c  "\
delete from chile_new.temp7_hydro_study_dates_export; \
INSERT INTO chile_new.temp7_hydro_study_dates_export \
  SELECT distinct period, year as projection_year, month_of_year, to_char(h.timestamp_cst, 'YYYYMMDD') AS date\
  FROM chile_new.timescales_set_timepoints \
  JOIN chile_new.hours_2060 h USING (hour_number)\
  WHERE timescales_set_id = $timescales_SET_ID;"
  
$connection_string -A -t -F  $'\t' -c  "delete from chile_new.hydro_monthly_limits_variable;"

$connection_string -A -t -F  $'\t' -c  "insert into chile_new.hydro_monthly_limits_variable \
	select project_id, avg_proj_yr as projection_year, month_of_year, avg(average_output_mw) as avg_out \
	from( \
	select project_id, projection_year, \
	CASE WHEN projection_year >= period_start and projection_year <= period_end THEN period_start END as avg_proj_yr, \
	month as month_of_year, average_output_mw \
	from chile_new.hydro_limits_ep_hydrologies \
	join chile_new.hydro_limits_ep_random_series using (n) \
	join \
	(select project_id, year, month, cap_fact_weigh * capacity_mw as average_output_mw \
	from chile_new.hydro_monthly_limits_1960_2010 \
	join chile_new.existing_plants_wo_hydro using (project_id) \
	where year > 1960 \
	order by 1,2,3) t1 using (year), \
	(select period_start, period_end \
	from chile_new.timescales_set_periods \
	where timescales_set_id = $timescales_SET_ID \
	order by 1) t3 \
	where n = $HYD_ID and projection_year >= period_start and projection_year <= period_end \
	order by 1,2,4 ) t2 \
	group by 1,2,3 order by 1,2,3;"

$connection_string -A -t -F  $'\t' -c  "SELECT project_id, la_id, technology, date, ROUND(cast(average_output_mw as numeric),1) AS average_output_mw \
  FROM chile_new.hydro_monthly_limits_variable hmle \
  JOIN chile_new.temp7_hydro_study_dates_export t ON hmle.projection_year = t.period and t.month_of_year = hmle.month_of_year \
  JOIN chile_new.existing_plants_wo_hydro using (project_id);" >> hydro_monthly_limits_ep.tab
  
 #JOIN temp7_hydro_study_dates_export USING (projection_year, month_of_year) \ 
  
echo '	hydro_monthly_limits_new.tab...'
echo ampl.tab 4 1 > hydro_monthly_limits_new.tab
echo 'project_id	la_id	technology	date	average_output_cf' >> hydro_monthly_limits_new.tab
$connection_string -A -t -F  $'\t' -c  "\
  CREATE TEMPORARY TABLE temp7_hydro_study_dates_export AS \
  SELECT distinct period, year as projection_year, month_of_year, to_char(h.timestamp_cst, 'YYYYMMDD') AS date \
  FROM chile_new.timescales_set_timepoints \
  JOIN chile_new.hours_2060 h USING (hour_number)\
  WHERE timescales_set_id = $timescales_SET_ID; \
  SELECT hmle.project_id, la_id, technology, date, ROUND(cast(average_output_cf as numeric),3) AS average_output_cf \
  FROM chile_new.hydro_monthly_limits_new_2060 hmle \
  JOIN temp7_hydro_study_dates_export USING (projection_year, month_of_year) \
  JOIN chile_new.new_projects_v4 USING (project_id);" >> hydro_monthly_limits_new.tab
  
  ########################################################
# CARBON CAP
  
# JP: This was added to allow carbon cap
# echo '	carbon_cap_targets.tab...'
# echo ampl.tab 1 1 > carbon_cap_targets.tab
# echo 'year carbon_emissions_relative_to_base' >> carbon_cap_targets.tab
# $connection_string -A -t -F  $'\t' -c  "select year, carbon_emissions_relative_to_base from chile_new.carbon_cap_targets_v2 \
# where year >= $STUDY_START_YEAR and year <= $STUDY_END_YEAR \
# and carbon_cap_id=$CARBON_CAP_ID AND $ENABLE_CARBON_CAP = 1;" >> carbon_cap_targets.tab


 ########################################################
# RENEWABLE PORTFOLIO STANDARDS
 
# echo '	rps_compliance_entity_targets.tab...'
# echo ampl.tab 3 1 > rps_compliance_entity_targets.tab
# echo 'rps_compliance_entity	rps_compliance_type	rps_compliance_year	rps_compliance_fraction' >> rps_compliance_entity_targets.tab
# $connection_string -A -t -F  $'\t' -c "select rps_compliance_entity, rps_compliance_type, rps_compliance_year, rps_compliance_fraction from chile_new.rps_compliance_entity_targets_v2 where enable_rps = $ENABLE_RPS AND rps_compliance_year >= $present_year and rps_compliance_year <= $STUDY_END_YEAR AND rps_id = $RPS_ID;" >> rps_compliance_entity_targets.tab

# echo '	rps_areas_and_fuel_category.tab...'
# echo ampl.tab 2 1 > rps_areas_and_fuel_category.tab
# echo 'la_id	fuel_category fuel_qualifies_for_rps' >> rps_areas_and_fuel_category.tab
# $connection_string -A -t -F  $'\t' -c "select la_id, fuel_category, fuel_qualifies_for_rps from chile_new.rps_areas_and_fuel_category;" >> rps_areas_and_fuel_category.tab

