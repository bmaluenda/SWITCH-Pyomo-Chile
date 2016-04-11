# Copyright 2015 The Switch Authors. All rights reserved.
# Licensed under the Apache License, Version 2, which is in the LICENSE file.

"""
Defines balacing area components for the SWITCH-Pyomo model.

SYNOPSIS
>>> from switch_mod.utilities import define_AbstractModel
>>> model = define_AbstractModel(
...     'timescales', 'load_zones', 'balancing_areas')
>>> instance = model.load_inputs(inputs_dir='test_dat')

"""
import os
from pyomo.environ import *


def define_components(mod):
    """

    Augments a Pyomo abstract model object with sets and parameters that
    describe balancing areas. Unless otherwise stated, each set and
    parameter is mandatory.

    lz_balancing_area[z] describes which balancing area each load zone
    belongs to.

    BALANCING_AREAS describes the set of balancing areas in which
    operational reserves must be met. These are the unique names
    specified in the lz_balancing_area[z] parameter. You can override
    the default operational reserve requirements (described below) by
    including an additional file in the input directory. See
    load_inputs() documentation for more details. Balancing areas
    are abbreviated as b for the purposed of indexing.

    quickstart_res_load_frac[b] describes the quickstart reserve
    requirements as a fraction of total load in the balancing area in
    each hour. This defaults to 0.03.

    quickstart_res_wind_frac[b] describes the quickstart reserve
    requirements as a fraction of wind energy produced in the balancing
    area in each hour. This defaults to 0.05.

    quickstart_res_solar_frac[b] describes the quickstart reserve
    requirements as a fraction of solar energy produced in the balancing
    area in each hour. This defaults to 0.05.

    spinning_res_load_frac[b] describes the spinning reserve
    requirements as a fraction of total load in the balancing area in
    each hour. This defaults to 0.03.

    spinning_res_wind_frac[b] describes the spinning reserve
    requirements as a fraction of wind energy produced in the balancing
    area in each hour. This defaults to 0.05.

    spinning_res_solar_frac[b] describes the spinning reserve
    requirements as a fraction of solar energy produced in the balancing
    area in each hour. This defaults to 0.05.

    """

    mod.lz_balancing_area = Param(mod.LOAD_ZONES)
    mod.min_data_check('lz_balancing_area')
    mod.BALANCING_AREAS = Set(initialize=lambda m: set(
        m.lz_balancing_area[z] for z in m.LOAD_ZONES))
    #Added this set for the reserves constraint
    mod.LOAD_ZONES_IN_BALANCING_AREA = Set(mod.BALANCING_AREAS, 
        initialize=lambda m, b: set(lz for lz in m.LOAD_ZONES 
            if m.lz_balancing_area[lz] == b ))

    mod.quickstart_res_load_frac = Param(
        mod.BALANCING_AREAS, within=PositiveReals, default=0.03,
        validate=lambda m, val, b: val < 1)
    mod.quickstart_res_wind_frac = Param(
        mod.BALANCING_AREAS, within=PositiveReals, default=0.05,
        validate=lambda m, val, b: val < 1)
    mod.quickstart_res_solar_frac = Param(
        mod.BALANCING_AREAS, within=PositiveReals, default=0.05,
        validate=lambda m, val, b: val < 1)
    mod.spinning_res_load_frac = Param(
        mod.BALANCING_AREAS, within=PositiveReals, default=0.03,
        validate=lambda m, val, b: val < 1)
    mod.spinning_res_wind_frac = Param(
        mod.BALANCING_AREAS, within=PositiveReals, default=0.05,
        validate=lambda m, val, b: val < 1)
    mod.spinning_res_solar_frac = Param(
        mod.BALANCING_AREAS, within=PositiveReals, default=0.05,
        validate=lambda m, val, b: val < 1)

def define_dynamic_components(mod):
    """
    Add balancing area reserves requirements
    Missing: create variables for reserves, add fuel consumption, constraint generation
    """
    mod.Spinning_Reserve_Req = Constraint(mod.BALANCING_AREAS, mod.TIMEPOINTS,
        rule = lambda m, b, t:(
            sum(m.SpinningReserveProj[proj, tp] 
                for (proj, tp) in m.PROJ_DISPATCH_POINTS if tp == t and m.proj_load_zone[proj] in m.LOAD_ZONES_IN_BALANCING_AREA[b])
            >=
            m.spinning_res_load_frac[b] * sum(m.lz_demand_mw[lz, t] 
                for lz in m.LOAD_ZONES_IN_BALANCING_AREA[b]) +
            m.spinning_res_wind_frac[b] * sum(m.ProjCapacityTP[proj, t] * m.proj_max_capacity_factor[proj, t] 
                for (proj, tp) in m.PROJ_DISPATCH_POINTS if m.g_energy_source[m.proj_gen_tech[proj]] == 'Wind' 
                and tp == t and m.proj_load_zone[proj] in m.LOAD_ZONES_IN_BALANCING_AREA[b]) +  
            m.spinning_res_solar_frac[b] * sum(m.ProjCapacityTP[proj, t] * m.proj_max_capacity_factor[proj, t] 
                for (proj, tp) in m.PROJ_DISPATCH_POINTS if m.g_energy_source[m.proj_gen_tech[proj]] == 'Solar' 
                and tp == t and m.proj_load_zone[proj] in m.LOAD_ZONES_IN_BALANCING_AREA[b])
            ))
    mod.Quickstart_Reserve_Req = Constraint(mod.BALANCING_AREAS, mod.TIMEPOINTS,
        rule = lambda m, b, t:(
            sum(m.QuickstartReserveProj[proj, tp] 
                for (proj, tp) in m.PROJ_DISPATCH_POINTS if tp == t and m.proj_load_zone[proj] in m.LOAD_ZONES_IN_BALANCING_AREA[b])
            >=
            m.quickstart_res_load_frac[b] * sum(m.lz_demand_mw[lz, t] 
                for lz in m.LOAD_ZONES_IN_BALANCING_AREA[b]) +
            m.quickstart_res_wind_frac[b] * sum(m.ProjCapacityTP[proj, t] * m.proj_max_capacity_factor[proj, t] 
                for (proj, tp) in m.PROJ_DISPATCH_POINTS if m.g_energy_source[m.proj_gen_tech[proj]] == 'Wind' 
                and tp == t and m.proj_load_zone[proj] in m.LOAD_ZONES_IN_BALANCING_AREA[b]) +
            m.quickstart_res_solar_frac[b] * sum(m.ProjCapacityTP[proj, t] * m.proj_max_capacity_factor[proj, t] 
                for (proj, tp) in m.PROJ_DISPATCH_POINTS if m.g_energy_source[m.proj_gen_tech[proj]] == 'Solar' 
                and tp == t and m.proj_load_zone[proj] in m.LOAD_ZONES_IN_BALANCING_AREA[b])
            ))

def load_inputs(mod, switch_data, inputs_dir):
    """

    Import balancing_area data. The following files are expected in the input
    directory:

    lz_balancing_areas.tab should be a tab-separated file with the columns:
        LOAD_ZONE, balancing_area

    balancing_areas.tab is optional and should be specified if you want
    to override the default values for operational reserves. If
    provided, it needs to be formatted as a tab-separated file with the
    columns:
        BALANCING_AREAS, quickstart_res_load_frac,
        quickstart_res_wind_frac, quickstart_res_solar_frac,
        spinning_res_load_frac, spinning_res_wind_frac,
        spinning_res_solar_frac

    """
    # Include select in each load() function so that it will check out
    # column names, be indifferent to column order, and throw an error
    # message if some columns are not found.
    switch_data.load(
        filename=os.path.join(inputs_dir, 'lz_balancing_areas.tab'),
        select=('LOAD_ZONE', 'balancing_area'),
        param=(mod.lz_balancing_area))
    path = os.path.join(inputs_dir, 'balancing_areas.tab')
    if os.path.isfile(path):
        # Load balancing area data from a file if it exists.
        switch_data.load(
            filename=path,
            select=(
                'BALANCING_AREAS', 'quickstart_res_load_frac',
                'quickstart_res_wind_frac', 'quickstart_res_solar_frac',
                'spinning_res_load_frac', 'spinning_res_wind_frac',
                'spinning_res_solar_frac'),
            param=(mod.quickstart_res_load_frac, mod.quickstart_res_wind_frac,
                   mod.quickstart_res_solar_frac, mod.spinning_res_load_frac,
                   mod.spinning_res_wind_frac, mod.spinning_res_solar_frac))
