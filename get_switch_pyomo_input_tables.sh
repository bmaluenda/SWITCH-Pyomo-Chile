#!/bin/bash
# The first line needs to stay #!/bin/bash to make this file a proper executable shell script. 

# present_year was forced to be 2011

# Date of creation: Spring 2016

# SWITCH CHILE!

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
connection_string="psql -h 127.0.0.1 -p 5433 -U bmaluenda -d switch_gis"

test_connection=`$connection_string -t -c "select count(*) from chile.load_area;"`

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
if [ $($connection_string -t -c "select count(*) from chile.scenarios_switch_chile where scenario_id=$SCENARIO_ID;") -eq 0 ]; then 
	echo "ERROR! This scenario id ($SCENARIO_ID) is not in the database. Exiting."
	exit;
fi

SCENARIO_NAME=$($connection_string -t -c "select scenario_name from chile.scenarios_switch_chile where scenario_id = $SCENARIO_ID;")
SCENARIO_NOTES=$($connection_string -t -c "select notes from chile.scenarios_switch_chile where scenario_id = $SCENARIO_ID;")

# HYD_ID is used to choose an inflow hydrological window. Windows are 18 years long and externally built in the DB.
# HYD_ID 1 is the interval 1960-1977 and HYD_ID 33 is 1992-2009.
export HYD_ID=$($connection_string -t -c "select hyd_id from chile.scenarios_switch_chile where scenario_id = $SCENARIO_ID;")

# Variable not used in model, only for documentation of the run.
export FROM_YEAR=$($connection_string -t -c "select from_year from chile.hydrological_window_reservoir_2 where hyd_id = $HYD_ID;")

export CARBON_CAP_ID=$($connection_string -t -c "select carbon_cap_id from chile.scenarios_switch_chile where scenario_id = $SCENARIO_ID;")

# Binary variable to know if a carbon cap is active or not. If its inactive, the cap constraint is dropped in load.run
ENABLE_CARBON_CAP=$($connection_string -t -c "select case when $CARBON_CAP_ID=0 then 0 else 1 end;")

export RPS_ID=$($connection_string -t -c "select rps_id from chile.scenarios_switch_chile where scenario_id = $SCENARIO_ID;")

# Binary variable to know if a RPS is active or not. If its inactive, the RPS constraint is dropped in load.run
ENABLE_RPS=$($connection_string -t -c "select case when $RPS_ID=0 then 0 else 1 end;")

# Binary variable to know if specific transmission constraints are active or not. If they are inactive (value 0), the Tx constraint is dropped in load.run
ENABLE_TX_CONSTRAINT=$($connection_string -t -c "select enable_tx_constraint from chile.scenarios_switch_chile where scenario_id = $SCENARIO_ID;")

# Binary variable to know if certain renewable capacities will be forced or not. If this is not wanted (value 0), the forced renewables constraint is dropped in load.run
ENABLE_FORCE_RENEWABLES=$($connection_string -t -c "select enable_force_renewables from chile.scenarios_switch_chile where scenario_id = $SCENARIO_ID;")

# Binary variable to know if SIC-SING interconection is possible or not. If this is not possible (value 0), that line is excluded from possible Tx builds
export SIC_SING_ID=$($connection_string -t -c "select sic_sing_id from chile.scenarios_switch_chile where scenario_id = $SCENARIO_ID;")

export FUEL_COST_ID=$($connection_string -t -c "select fuel_cost_id from chile.scenarios_switch_chile where scenario_id = $SCENARIO_ID;")

export OVERNIGHT_COST_ID=$($connection_string -t -c "select overnight_cost_id from chile.scenarios_switch_chile where scenario_id = $SCENARIO_ID;")

export NEW_PROJECT_PORTFOLIO_ID=$($connection_string -t -c "select new_project_portfolio_id from chile.scenarios_switch_chile where scenario_id = $SCENARIO_ID;")

#The Training Set determines the demand scenario, number of Tps, start year, years per period, number of periods, etc.
export TRAINING_SET_ID=$($connection_string -t -c "select training_set_id from chile.scenarios_switch_chile where scenario_id = $SCENARIO_ID;")
TRAINING_SET_NOTES=$($connection_string -t -c "select notes from chile.training_sets where training_set_id = $TRAINING_SET_ID;")

export DEMAND_SCENARIO_ID=$($connection_string -t -c "select demand_scenario_id from chile.training_sets where training_set_id = $TRAINING_SET_ID;")

export STUDY_START_YEAR=$($connection_string -t -c "select study_start_year from chile.training_sets where training_set_id=$TRAINING_SET_ID;")

export STUDY_END_YEAR=$($connection_string -t -c "select study_start_year + years_per_period*number_of_periods from chile.training_sets where training_set_id=$TRAINING_SET_ID;")

number_of_years_per_period=$($connection_string -t -c "select years_per_period from chile.training_sets where training_set_id=$TRAINING_SET_ID;")

number_of_timepoints=$($connection_string -t -c "select number_of_timepoints from chile.training_sets where training_set_id=$TRAINING_SET_ID;")

number_of_periods=$($connection_string -t -c "select number_of_periods from chile.training_sets where training_set_id=$TRAINING_SET_ID;")

# get the present year that will make present day cost optimization possible
#present_year=$($connection_string -t -c "select extract(year from now());")
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
echo "RPS enabled: $ENABLE_RPS"  >> scenario_params_doc.txt
echo "RPS ID: $RPS_ID"  >> scenario_params_doc.txt
echo "Carbon caps enabled: $ENABLE_CARBON_CAP"  >> scenario_params_doc.txt
echo "Carbon cap ID: $CARBON_CAP_ID" >>  scenario_params_doc.txt
echo "Tx constraint enabled: $ENABLE_TX_CONSTRAINT"  >> scenario_params_doc.txt
echo "SIC-SING Interconection enabled: $SIC_SING_ID"  >> scenario_params_doc.txt
echo "Fuel costs ID: $FUEL_COST_ID"  >> scenario_params_doc.txt
echo "New project portfolio ID: $NEW_PROJECT_PORTFOLIO_ID"  >> scenario_params_doc.txt
echo "Forced renewable plan: $ENABLE_FORCE_RENEWABLES"  >> scenario_params_doc.txt
echo "Training set ID: $TRAINING_SET_ID"  >> scenario_params_doc.txt
echo "Training set notes:$TRAINING_SET_NOTES"  >> scenario_params_doc.txt
echo "Demand scenario ID: $DEMAND_SCENARIO_ID"  >> scenario_params_doc.txt
echo "Years per period: $number_of_years_per_period"  >> scenario_params_doc.txt
echo "Number of timepoints: $number_of_timepoints"  >> scenario_params_doc.txt
echo "Number of periods: $number_of_periods"  >> scenario_params_doc.txt
echo "Study start year: $STUDY_START_YEAR"  >> scenario_params_doc.txt
echo "Study end year: $STUDY_END_YEAR"  >> scenario_params_doc.txt
echo "Present year for discounted costs: $present_year"  >> scenario_params_doc.txt

echo 'Writing required modules for simulation'
echo 'local_td' >> modules
echo 'project.no_commit' >> modules
echo 'fuel_cost' >> modules
echo 'trans_build' >> modules
echo 'trans_dispatch' >> modules
echo 'balancing_areas' >> modules

# The format for tab files is:
# col1_name col2_name ...
# [rows of data]

# The format for dat files is the same as in AMPL dat files.

echo $'\nStarting data copying from the database to input files\n'

########################################################
# TIMESCALES

echo '	periods.tab...'
echo -e 'INVESTMENT_PERIOD\tperiod_start\tperiod_end' >> periods.tab
$connection_string -A -t -F  $'\t' -c "SELECT period_start, \
period_start, period_end \
FROM chile.training_set_periods \
WHERE training_set_id=$TRAINING_SET_ID ORDER BY period_start;" >> periods.tab

#Timeseries are a new feature in Pyomo, which is more flexible than the "date" index in AMPL
#Thus, It is impossible to define it with automated queries.
#In the following query, it is assumed that each timeseries represent certain amount of hours of a SINGLE DAY.
echo '	timeseries.tab...'
echo -e 'TIMESERIES\tts_period\tts_duration_of_tp\tts_num_tps\tts_scale_to_period' >> timeseries.tab
$connection_string -A -t -F  $'\t' -c "SELECT DISTINCT to_char(tps.timestamp_cst, 'YYYYMMDD'), period, hours_between_samples,\
24/hours_between_samples, hours_in_sample/hours_between_samples
FROM  chile.training_sets tss, chile.training_set_timepoints tps
WHERE (tss.training_set_id = tps.training_set_id and tss.training_set_id = $TRAINING_SET_ID) ORDER BY 1;" >> timeseries.tab

echo '	timepoints.tab...'
echo 'timepoint_id	timestamp	timeseries' >> timepoints.tab
$connection_string -A -t -F  $'\t' -c "SELECT hour_number, \
to_char(tps.timestamp_cst, 'YYYYMMDDHH24'), to_char(tps.timestamp_cst, 'YYYYMMDD')
FROM  chile.training_set_timepoints tps
WHERE training_set_id = $TRAINING_SET_ID ORDER BY 1;" >> timepoints.tab

########################################################
# LOAD ZONES AND BALANCING AREAS

#Since zonal economic multipliers are not being used in the Chile version, no data is availble in the DB. A default value of 1 is used.
#Existing T&D is assumed to be just enough to cover the peak demand in the period (50% of the period, actually) and the planning reserves (fixed at 0.15 in the Chile model)
#In Pyomo, its only necessary to cover the peaks in demand
#A generalization and better data are necessary
#AMPL takes into account the costs of operating current TD infrastructure, while Pyomo only accounts for new builds
echo '	load_zones.tab...'
echo -e 'LOAD_ZONE\tlz_cost_multipliers\tlz_ccs_distance_km\tlz_dbid\texisting_local_td\tlocal_td_annual_cost_per_mw' >>load_zones.tab
$connection_string -A -t -F  $'\t' -c  "SELECT ALL la_id, '1.0', ccs_distance_km, la_id_num,  present_day_max_coincident_demand_mwh_for_distribution*(1+0.15),\
CASE WHEN distribution_new_annual_payment_per_mw = 0 THEN '0.01' ELSE distribution_new_annual_payment_per_mw END
FROM chile.load_area;" >> load_zones.tab

echo '	loads.tab...'
echo -e 'LOAD_ZONE\tTIMEPOINT\tlz_demand_mw' >> loads.tab
$connection_string -A -t -F  $'\t' -c  "SELECT la.la_id, la.hour_number, la.la_demand_mwh 
FROM chile.la_hourly_demand_2060 la \
JOIN chile.training_sets USING (demand_scenario_id) \
JOIN chile.training_set_timepoints USING (training_set_id, hour_number)
WHERE demand_scenario_id = $DEMAND_SCENARIO_ID \
AND training_set_id = $TRAINING_SET_ID
ORDER BY la_id, hour_number;" >> loads.tab

#Required reserves in AMPL are calculated acording to available solar and wind capacity to be dispatched in each lz and tp. This doesn't take into account that you can disconnect a plant (spill all of its power), precisely because you want to avoid the need for further reserves.
echo '	balancing_areas.tab...'
echo -e 'BALANCING_AREAS\tquickstart_res_load_frac\tquickstart_res_wind_frac\tquickstart_res_solar_frac\tspinning_res_load_frac\tspinning_res_wind_frac\tspinning_res_solar_frac' >> balancing_areas.tab
$connection_string -A -t -F  $'\t' -c  "SELECT la_system,\
quickstart_requirement_relative_to_spinning_reserve_requirement*load_only_spinning_reserve_requirement, \
quickstart_requirement_relative_to_spinning_reserve_requirement*wind_spinning_reserve_requirement, \
quickstart_requirement_relative_to_spinning_reserve_requirement*solar_spinning_reserve_requirement, \
load_only_spinning_reserve_requirement, wind_spinning_reserve_requirement, \
solar_spinning_reserve_requirement
FROM chile.regional_grid_companies
;" >> balancing_areas.tab

echo '	lz_balancing_areas.tab...'
echo -e 'LOAD_ZONE\tbalancing_area'>>lz_balancing_areas.tab
$connection_string -A -t -F  $'\t' -c "SELECT la_id, regional_grid_company
FROM chile.load_area;">>lz_balancing_areas.tab

#Peak demand is only expected to be met until de 50% of the time inside each period. This is weird, but is a best approximation considering the model.
echo '	lz_peak_loads.tab'
echo -e 'LOAD_ZONE\tPERIOD\tpeak_demand_mw' >> lz_peak_loads.tab
$connection_string -A -t -F  $'\t' -c  "SELECT la_id, period_start, max(la_demand_mwh)
FROM chile.la_hourly_demand_2060 
    JOIN chile.training_sets USING (demand_scenario_id)  
    JOIN chile.training_set_periods USING (training_set_id)  
	JOIN chile.hours_2060 USING (hour_number)  
	JOIN chile.load_area USING (la_id) 
  WHERE training_set_id = $TRAINING_SET_ID  
    AND year = FLOOR( period_start + years_per_period/2) 
  GROUP BY la_id, period_start
  ORDER BY 1,2;">>lz_peak_loads.tab

  
########################################################
# CARBON CAP
  
# JP: This was added to allow carbon cap
# echo '	carbon_cap_targets.tab...'
# echo ampl.tab 1 1 > carbon_cap_targets.tab
# echo 'year carbon_emissions_relative_to_base' >> carbon_cap_targets.tab
# $connection_string -A -t -F  $'\t' -c  "select year, carbon_emissions_relative_to_base from chile.carbon_cap_targets_v2 \
# where year >= $STUDY_START_YEAR and year <= $STUDY_END_YEAR \
# and carbon_cap_id=$CARBON_CAP_ID AND $ENABLE_CARBON_CAP = 1;" >> carbon_cap_targets.tab

########################################################
# TRANSMISSION

#SIC-SING interconection is always assumed to be built.
#Tx lines in Pyomo must not have directionality in this input file (hence the inequality in the WHERE clause)
echo '	transmission_lines.tab...'
echo -e 'TRANSMISSION_LINE\ttrans_lz1\ttrans_lz2\ttrans_length_km\ttrans_efficiency\texisting_trans_cap' >>transmission_lines.tab
$connection_string -A -t -F  $'\t' -c  "SELECT transmission_line_id, \
la_start, la_end, CASE WHEN transmission_length_km = 0 THEN '0.01' ELSE transmission_length_km END, transmission_efficiency, CASE WHEN existing_transfer_capacity_mw = 0 THEN '0.01' ELSE existing_transfer_capacity_mw END
FROM chile.transmission_between_la
WHERE la_start < la_end ORDER BY 2,3;">>transmission_lines.tab	

#No derating factors or multipliers are used in Switch Chile
#\CASE WHEN new_transmission_builds_allowed = 1 THEN 1 ELSE 0 END
echo '	trans_optional_params.tab...'
echo -e 'TRANSMISSION_LINE\ttrans_dbid\ttrans_derating_factor\ttrans_terrain_multiplier\ttrans_new_build_allowed' >>trans_optional_params.tab
$connection_string -A -t -F  $'\t' -c  "SELECT transmission_line_id, transmission_line_id, '.', '.', '.'
FROM chile.transmission_between_la
WHERE la_start < la_end ORDER BY 1;">>trans_optional_params.tab	

#All the following params are taken from the AMPL model and don't change between simulations. Should be updated and revised.
echo '	trans_params.dat...'
echo 'param trans_capital_cost_per_mw_km:=1000;'>>trans_params.dat
echo 'param trans_lifetime_yrs:=20;'>>trans_params.dat
echo 'param trans_fixed_o_m_fraction:=0.03;'>>trans_params.dat
echo 'param distribution_loss_rate:=0.0652;'>>trans_params.dat

########################################################
# FUEL

#Only "fossilish" fuels are considered for now, because I don't know how Storage is treated in the new Pyomo modules
#Storage is just considered as an energy source for now
#Upstream carbon is set to 0 (the default value), because no information exists in the Chile DB
#Biomass is treated as a fuel in Pyomo
#Water is treated as a fuel in the DB unless its Water_RPS
#Took water into non_fuel to avoid errors
echo '	fuels.tab...'
echo -e 'fuel\tco2_intensity\tupstream_co2_intensity' >> fuels.tab
$connection_string -A -t -F  $'\t' -c  "SELECT fuel, \
carbon_content_without_carbon_accounting, 0
FROM chile.fuel_info
WHERE (rps_fuel_category = 'fossilish' OR biofuel = true) AND fuel <> 'Water';" >> fuels.tab

echo '	non_fuel_energy_sources.tab...'
echo 'energy_source' >> non_fuel_energy_sources.tab
$connection_string -A -t -F  $'\t' -c  "SELECT fuel
FROM chile.fuel_info
WHERE (rps_fuel_category = 'renewable' AND biofuel = false) OR fuel = 'Water' OR fuel = 'Storage';">> non_fuel_energy_sources.tab

#Data is averaged in each period from the yearly projected values in the DB
echo '	fuel_cost.tab'
echo -e 'load_zone\tfuel\tperiod\tfuel_cost' >> fuel_cost.tab
$connection_string -A -t -F  $'\t' -c  "SELECT la_id, \
fuel, period_start, AVG(fuel_price)
FROM (
SELECT la_id, fp.fuel, projection_year, fuel_price, fuel_cost_id 
FROM chile.fuel_prices fp
JOIN chile.fuel_info fi  USING (fuel)
WHERE (rps_fuel_category = 'fossilish' OR biofuel = TRUE) AND fp.fuel <> 'Water'
) AS pyomo_fuel_info 
CROSS JOIN chile.training_set_periods
WHERE fuel_cost_id = $FUEL_COST_ID AND training_set_id = $TRAINING_SET_ID AND projection_year >= period_start AND projection_year <= period_end
GROUP BY la_id, fuel, period_start ORDER BY la_id, fuel, period_start;" >> fuel_cost.tab


#TODO: Implement fuel markets in Pyomo for Biomass and NG.


########################################################
# PLANTS

#Projects in Pyomo are approach at a bit differently: all projects are listed in this file, regardless of if they exist or not. Existing projects' capacities are specified in the next file. So, a UNION must be implemented.
#Outage rates are defaulted to the generic technology.
#Existing projects are not allowed to be expanded in AMPL, so their capacity limit is set to their current capacity.
#In the AMPL model capacity limits are only enforced for projects which are "resource_limited".
#Careful with solar central station projects, because there are extra constraints in AMPL that use an additional capacity parameter (capacity_limit_conversion).
#Parameters that don't apply to certain projects must be defaulted to a dot ('.') or Pyomo will raise an error.

echo '	project_info.tab...'
echo -e 'PROJECT\tproj_gen_tech\tproj_load_zone\tproj_connect_cost_per_mw\tproj_variable_om\tproj_full_load_heat_rate\tproj_forced_outage_rate\tproj_scheduled_outage_rate\tproj_dbid\tproj_capacity_limit_mw' >> project_info.tab
$connection_string -A -t -F  $'\t' -c  "SELECT plant_name, \
technology, la_id, connect_cost_per_mw, variable_o_m, \
CASE WHEN heat_rate>0 THEN TO_CHAR(heat_rate::real,'999D9') ELSE '.' END, \
'.', '.', project_id, TO_CHAR(capacity_mw::real, '999D9')
FROM chile.existing_plants_wo_hydro
WHERE complete_data AND project_id <> 'SING2' AND project_id <> 'SING3' AND project_id <> 'SING4' AND project_id <> 'SING5'
UNION
SELECT TO_CHAR(np.project_id, '999'), np.technology, np.la_id, np.connect_cost_per_mw, \
gi.variable_o_m, CASE WHEN np.heat_rate>0 THEN TO_CHAR(np.heat_rate::real,'999D9') ELSE '.' END, \
'.', '.', TO_CHAR(np.project_id, '999'), CASE WHEN resource_limited THEN TO_CHAR(np.capacity_limit * np.capacity_limit_conversion::real,'9999D9') ELSE '.' END
FROM chile.new_projects_v4 np
JOIN chile.generator_info_v2 gi USING (technology_id)
JOIN chile.new_projects_scenarios ps USING (project_id)
WHERE ps.new_project_portfolio_id = $NEW_PROJECT_PORTFOLIO_ID
ORDER BY 2,1;">> project_info.tab

#Projects SING2, SING3, SING4 and SING5 are RoR plants in the northern system, for which there is no available hydro info in the DB, so they are excluded.

echo '	proj_existing_builds.tab...'
echo -e 'PROJECT\tbuild_year\tproj_existing_cap' >> proj_existing_builds.tab
$connection_string -A -t -F  $'\t' -c  "SELECT plant_name, \
start_year, capacity_mw
FROM chile.existing_plants_wo_hydro
WHERE complete_data AND project_id <> 'SING2' 
AND project_id <> 'SING3' AND project_id <> 'SING4' 
AND project_id <> 'SING5';">> proj_existing_builds.tab

#Existing projects must have their overnight costs specified here.
echo '	proj_build_costs.tab...'
echo -e 'PROJECT\tbuild_year\tproj_overnight_cost\tproj_fixed_om' >> proj_build_costs.tab
$connection_string -A -t -F  $'\t' -c  "SELECT plant_name, \
start_year, overnight_cost, fixed_o_m
FROM chile.existing_plants_wo_hydro
WHERE complete_data AND project_id <> 'SING2' 
AND project_id <> 'SING3' AND project_id <> 'SING4' 
AND project_id <> 'SING5';" >> proj_build_costs.tab

########################################################
# GENERATOR TECHNOLOGIES

#Unit Sizes are not implemented, since there is no info in the AMPL DB
#CCS energy loads are not defined in AMPL, so no info is available
#Battery storage may cause problems
#Care must be exercised when defining parameters that do not apply to all technologies, such as heat rate (i.e. heat rate means nothing to solar PV technologies). A value of 0 is written by default from the DB, but Pyomo needs a dot ('.') when a parameter doesn't apply.
#"Water fueled" plants (RoR and dams) are marked as variable, since in Pyomo that means they have an exogenous constraint on their production (which is how hydro plants are modelled in Switch-Chile for now).

echo '	generator_info.tab'
echo -e 'generation_technology\tg_max_age\tg_is_variable\tg_is_baseload\tg_is_flexible_baseload\tg_is_cogen\tg_competes_for_space\tg_variable_o_m\tg_energy_source\tg_dbid\tg_scheduled_outage_rate\tg_forced_outage_rate\tg_min_build_capacity\tg_full_load_heat_rate\tg_unit_size\tg_ccs_capture_efficiency\tg_ccs_energy_load\tg_storage_efficiency\tg_store_to_release_ratio' >> generator_info.tab
$connection_string -A -t -F  $'\t' -c  "SELECT technology, \
max_age_years, CASE WHEN intermittent OR fuel = 'Water' OR fuel = 'Water_RPS' THEN 1 ELSE 0 END, \
CASE WHEN baseload THEN 1 ELSE 0 END, \
CASE WHEN flexible_baseload THEN 1 ELSE 0 END, \
CASE WHEN cogen THEN 1 ELSE 0 END, \
CASE WHEN competes_for_space THEN 1 ELSE 0 END, \
variable_o_m, fuel, technology_id, scheduled_outage_rate, \
forced_outage_rate, min_build_capacity, \
CASE WHEN heat_rate>0 THEN TO_CHAR(heat_rate::real, '999D9') ELSE '.' END, '.', \
CASE WHEN carbon_content_without_carbon_accounting>0 THEN carbon_sequestered/carbon_content_without_carbon_accounting ELSE 0 END, \
'.', \
storage_efficiency, CASE WHEN max_store_rate > 0 THEN TO_CHAR(max_store_rate::real, '999D9') ELSE '.' END
FROM chile.generator_info_v2 
JOIN chile.fuel_info USING (fuel) 
ORDER BY technology_id;" >> generator_info.tab

#A fixed_o_m of 0 is specified for all technologies, since in the
#Chilean DB that datus is specified per project
#(and in the Pyomo implementation project info overwrites generic technological parameters)
#I don't know how the cost is sampled for each period, because this WHERE clause results in more than one cost per period. To solve this, I simply averaged the results of the query.
echo '	gen_new_build_costs.tab...'
echo -e 'generation_technology\tinvestment_period\tg_overnight_cost\tg_fixed_o_m' >> gen_new_build_costs.tab
$connection_string -A -t -F  $'\t' -c  "SELECT gc.technology, \
period_start, AVG(gc.overnight_cost), gi.fixed_o_m
FROM chile.generator_info_v2 gi 
JOIN chile.generator_costs_yearly gc USING (technology), chile.training_set_periods
WHERE year >= period_start
AND year <= period_end
AND period_start >= $present_year \
AND	period_start >= gi.min_build_year \
AND training_set_id=$TRAINING_SET_ID \
AND overnight_cost_id=$OVERNIGHT_COST_ID
GROUP BY gc.technology, period_start, gi.fixed_o_m
ORDER BY technology, period_start;">>gen_new_build_costs.tab

#Eliminated current costs to avoid error in loading inputs to Pyomo.
# UNION
# SELECT gc.technology, year, gc.overnight_cost, gi.fixed_o_m
# FROM chile.generator_info_v2 gi 
# JOIN chile.generator_costs_yearly gc USING (technology), chile.training_set_periods
# WHERE year = $present_year
# AND training_set_id=$TRAINING_SET_ID \
# AND overnight_cost_id=$OVERNIGHT_COST_ID



########################################################
# FINANCIALS

echo '	financials.dat...'
echo 'param base_financial_year := 2014;'>>financials.dat
echo 'param interest_rate := .07;'>>financials.dat
echo 'param discount_rate := .07;'>>financials.dat

########################################################
# VARIABLE CAPACITY FACTORS

#This convolusion of JOINS must be implemented because intermittent capacity factors are only defined until a certain year (I don't know which one). So, 2014 values are repeated yearly and timepoints are matched by hour and month.

#A UNION must be implemented to stitch together capacity factors from new and existing plants that are not RoR

#For some reason, only certain existing wind plants and RoR plants were taken into account in the original script. I will leave them like that to validate the model first.

#The second UNION incorporates the capacity factors from new 
echo '	variable_capacity_factors.tab... inserting non-RoR'
echo -e 'PROJECT\ttimepoint\tproj_max_capacity_factor' >>variable_capacity_factors.tab
$connection_string -A -t -F  $'\t' -c  "
SELECT TO_CHAR(project_id, '999'), t3.hour_number, CASE WHEN capacity_factor>1.999 THEN 1.999 ELSE capacity_factor END
	FROM(
		SELECT project_id, la_id, month_of_year, hour_of_year, hour_of_day, capacity_factor
		FROM chile.new_projects_intermittent_capacity_factor_puc
		JOIN chile.hours_2060 h USING (hour_number)
		WHERE year = 2014 ) t1
	JOIN chile.new_projects_v4 USING (project_id, la_id)
	JOIN (SELECT distinct year, t.hour_of_year, t.timestamp_cst, hour_number 
			FROM chile.training_set_timepoints t
			JOIN chile.hours_2060 USING (hour_number)
			WHERE training_set_id = $TRAINING_SET_ID ORDER BY 1,2) t3 USING (hour_of_year)
	JOIN chile.new_projects_scenarios USING (project_id)
	WHERE new_project_portfolio_id = $NEW_PROJECT_PORTFOLIO_ID
UNION
SELECT plant_name, t3.hour_number, capacity_factor
	FROM(
		SELECT project_id, la_id, month_of_year, hour_of_year, hour_of_day, capacity_factor
		FROM chile.existing_plant_intermittent_capacity_factor
		JOIN chile.hours_2060 h using (hour_number, hour_of_year)
		WHERE year = 2014 ) t1
	JOIN chile.existing_plants_wo_hydro using (project_id, la_id)
	JOIN (SELECT distinct year, t.hour_of_year, t.timestamp_cst, hour_number
		FROM chile.training_set_timepoints t
		JOIN chile.hours_2060 USING (hour_number)
		WHERE training_set_id = $TRAINING_SET_ID ORDER BY 1,2) t3 USING (hour_of_year)
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
from chile.hydro_limits_ep_hydrologies \
join chile.hydro_limits_ep_random_series using (n) \
join \
(select project_id, year, month, adj_factor \
from \
( \
select project_id, hydro_year, tstampyear as year, month, \
CASE WHEN avg_capacity_factor = 0 THEN 1 ELSE escalated_cap_fact/avg_capacity_factor END as adj_factor \
from chile.escalated_historic_cap_fact_final_2 \
join (select * from chile.existing_plant_intermittent_capacity_factor_monthly where year = 2014) t1 using (project_id, month) \
order by 1,3,4 \
) t4 \
where year > 1960 \
order by 1,2,3) t1 using (year), \
(select period_start, period_end \
from chile.training_set_periods \
where training_set_id = $TRAINING_SET_ID \
order by 1) t3 \
where n = $HYD_ID and projection_year >= period_start and projection_year <= period_end \
order by 1,2,4) t2 \
group by 1,2,3 order by 1,2,3;"
 
#Capacity factors from the temorary table are inserted into the tab file
$connection_string -A -t -F  $'\t' -c "SELECT plant_name, tps.hour_number, CASE WHEN AVG(capacity_factor * avg_adj_factor) > 1.4 THEN 1.4 ELSE AVG(capacity_factor * avg_adj_factor) END
FROM (
	SELECT project_id, la_id, hour_of_year, month_of_year, capacity_factor, hour_number
	FROM chile.existing_plant_intermittent_capacity_factor
	JOIN chile.hours_2060 h USING (hour_number, hour_of_year)
		WHERE year = 2014 ) t1
JOIN chile.existing_plants_wo_hydro USING (project_id, la_id)
JOIN (SELECT DISTINCT period as projection_year, t.hour_of_year
	FROM chile.training_set_timepoints t
	WHERE training_set_id = $TRAINING_SET_ID order by 1,2) t3
	USING (hour_of_year)
JOIN chile.temp_hydro_ror_ep_adjustment_factors 
	USING (project_id, projection_year, month_of_year)
JOIN chile.training_set_timepoints tps ON tps.hour_of_year = t3.hour_of_year AND tps.training_set_id = $TRAINING_SET_ID
WHERE technology <> 'Hydro_NonPumped' AND project_id NOT IN ('SIC70','SIC71','SIC72','SIC73','SIC74','SIC17','SIC32','SIC42','SIC48','SIC49','SIC53')
GROUP BY plant_name, tps.hour_number
ORDER BY 1,2;" >> variable_capacity_factors.tab

#I add placeholders for Hydro_NonPumped and Hydro_NonPumped_New generators, because no capacity factor data is available for them, but Pyomo needs the input to exist.

$connection_string -A -t -F  $'\t' -c "SELECT plant_name, \
hour_number, '0.01'
FROM chile.existing_plants_wo_hydro
CROSS JOIN chile.training_set_timepoints 
WHERE technology = 'Hydro_NonPumped' AND training_set_id = $TRAINING_SET_ID
ORDER BY 1,2 ;" >> variable_capacity_factors.tab

$connection_string -A -t -F  $'\t' -c "SELECT TO_CHAR(project_id, '999'), hour_number, '0.01'
FROM chile.new_projects_v4 np
CROSS JOIN chile.training_set_timepoints
JOIN chile.new_projects_scenarios USING (project_id) 
WHERE technology = 'Hydro_NonPumped_New' AND training_set_id = $TRAINING_SET_ID AND new_project_portfolio_id=$NEW_PROJECT_PORTFOLIO_ID 
ORDER BY 1,2 ;" >> variable_capacity_factors.tab

 ########################################################
# RENEWABLE PORTFOLIO STANDARDS
 
# echo '	rps_compliance_entity_targets.tab...'
# echo ampl.tab 3 1 > rps_compliance_entity_targets.tab
# echo 'rps_compliance_entity	rps_compliance_type	rps_compliance_year	rps_compliance_fraction' >> rps_compliance_entity_targets.tab
# $connection_string -A -t -F  $'\t' -c "select rps_compliance_entity, rps_compliance_type, rps_compliance_year, rps_compliance_fraction from chile.rps_compliance_entity_targets_v2 where enable_rps = $ENABLE_RPS AND rps_compliance_year >= $present_year and rps_compliance_year <= $STUDY_END_YEAR AND rps_id = $RPS_ID;" >> rps_compliance_entity_targets.tab

# echo '	rps_areas_and_fuel_category.tab...'
# echo ampl.tab 2 1 > rps_areas_and_fuel_category.tab
# echo 'la_id	fuel_category fuel_qualifies_for_rps' >> rps_areas_and_fuel_category.tab
# $connection_string -A -t -F  $'\t' -c "select la_id, fuel_category, fuel_qualifies_for_rps from chile.rps_areas_and_fuel_category;" >> rps_areas_and_fuel_category.tab


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
delete from chile.temp7_hydro_study_dates_export; \
INSERT INTO chile.temp7_hydro_study_dates_export \
  SELECT distinct period, year as projection_year, month_of_year, to_char(h.timestamp_cst, 'YYYYMMDD') AS date\
  FROM chile.training_set_timepoints \
  JOIN chile.hours_2060 h USING (hour_number)\
  WHERE training_set_id = $TRAINING_SET_ID;"
  
$connection_string -A -t -F  $'\t' -c  "delete from chile.hydro_monthly_limits_variable;"

$connection_string -A -t -F  $'\t' -c  "insert into chile.hydro_monthly_limits_variable \
	select project_id, avg_proj_yr as projection_year, month_of_year, avg(average_output_mw) as avg_out \
	from( \
	select project_id, projection_year, \
	CASE WHEN projection_year >= period_start and projection_year <= period_end THEN period_start END as avg_proj_yr, \
	month as month_of_year, average_output_mw \
	from chile.hydro_limits_ep_hydrologies \
	join chile.hydro_limits_ep_random_series using (n) \
	join \
	(select project_id, year, month, cap_fact_weigh * capacity_mw as average_output_mw \
	from chile.hydro_monthly_limits_1960_2010 \
	join chile.existing_plants_wo_hydro using (project_id) \
	where year > 1960 \
	order by 1,2,3) t1 using (year), \
	(select period_start, period_end \
	from chile.training_set_periods \
	where training_set_id = $TRAINING_SET_ID \
	order by 1) t3 \
	where n = $HYD_ID and projection_year >= period_start and projection_year <= period_end \
	order by 1,2,4 ) t2 \
	group by 1,2,3 order by 1,2,3;"

$connection_string -A -t -F  $'\t' -c  "SELECT project_id, la_id, technology, date, ROUND(cast(average_output_mw as numeric),1) AS average_output_mw \
  FROM chile.hydro_monthly_limits_variable hmle \
  JOIN chile.temp7_hydro_study_dates_export t ON hmle.projection_year = t.period and t.month_of_year = hmle.month_of_year \
  JOIN chile.existing_plants_wo_hydro using (project_id);" >> hydro_monthly_limits_ep.tab
  
 #JOIN temp7_hydro_study_dates_export USING (projection_year, month_of_year) \ 
  
echo '	hydro_monthly_limits_new.tab...'
echo ampl.tab 4 1 > hydro_monthly_limits_new.tab
echo 'project_id	la_id	technology	date	average_output_cf' >> hydro_monthly_limits_new.tab
$connection_string -A -t -F  $'\t' -c  "\
  CREATE TEMPORARY TABLE temp7_hydro_study_dates_export AS \
  SELECT distinct period, year as projection_year, month_of_year, to_char(h.timestamp_cst, 'YYYYMMDD') AS date \
  FROM chile.training_set_timepoints \
  JOIN chile.hours_2060 h USING (hour_number)\
  WHERE training_set_id = $TRAINING_SET_ID; \
  SELECT hmle.project_id, la_id, technology, date, ROUND(cast(average_output_cf as numeric),3) AS average_output_cf \
  FROM chile.hydro_monthly_limits_new_2060 hmle \
  JOIN temp7_hydro_study_dates_export USING (projection_year, month_of_year) \
  JOIN chile.new_projects_v4 USING (project_id);" >> hydro_monthly_limits_new.tab




