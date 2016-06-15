# Copyright 2016 The Switch Authors. All rights reserved.
# Licensed under the Apache License, Version 2, which is in the LICENSE file.

"""

Generate .dat files required by the PySP pyomo module, either for use with the
runef or runph commands. This script serves only as a specific example in
order to learn how the runef and runph commands work and does not pretend to
be able to generate any scenario structure in a most flexible way. More 
versatility will be coded in the future.

This generator considers a two stage optimization problem, where all scenarios
have the same probability of ocurring. The ScenarioBasedData PySP parameter is
set to false in order to specify input data per node instead of per scenario.
This has the advantage of reducing the amount of data that has to be generated
and fed to the model, since usually only some parameters are subject to
stochasticity and the rest are scenario-independent.

The script requires a complete set of deterministic inputs in order to
generate the root node data. This set should be contained in an inputs_dir.
The generated files will be stored in a subdirectory located inside the
inputs_dir.

Created files:

RootNode.dat
    This file specifies all parameters on the root node of the scenario tree.
    Whichever parameter is subject to stochasticity will have to be included
    in the second stage nodes' .dat files. The benefit of the nodal approach
    is that only parameters that are scenario dependent must be specified
    again in the other nodes' .dat files. I.e., if only fuel costs vary from
    node to node, then only the fuel_cost parameter must be specified in the
    .dat files. If a non-root node has an empty .dat file, then PySP will
    asume that such node has the same parameter values as its parent node.  

ScenarioStructure.dat
    This file specifies the structure of the scenario tree. Refer to the PySP
    documentation for detailed definitions on each of the parameters. In this
    two stage example leaf nodes are named after the scenarios they belong to.
    The Expressions or Variables that define the stage costs are named after 
    the stage they belong to. These names must match the actual names of the
    Expressions and Variables in the Reference Model.

Leaf node files are not created by this script. Example .dat files are
provided instead, but can be modified at will in order to experiment
with different uncertainties. In case their names are changed, the
scenario_list should be modified to reflect those changes.

"""
# Inputs directory relative to the location of this script.
inputs_dir = "inputs"
# ScenarioStructure.dat and RootNode.dat will be saved to a
# subdirectory in the inputs folder.
pysp_subdir = "pysp_inputs"

# Stage names. Can be any string and must be specified in order.
stage_list = [
    "Investment", "Operation"]
    
# First stage variables
build_vars = [
    "BuildProj", "BuildLocalTD", "BuildTrans"]
# Second stage variables
operate_vars = [
    "DispatchProj", "ProjFuelUseRate"]
# List of scenario names
scenario_list = [
    "LowFuelCosts", "MediumFuelCosts", "HighFuelCosts"]

###########################################################

import switch_mod.utilities as utilities
import sys, os
from pyomo.environ import *

print "creating model for scenario input generation..."

try:
    module_fh = open(os.path.join(inputs_dir, 'modules'), 'r')
except IOError, exc:
    sys.exit('Failed to open input file: {}'.format(exc))
module_list = [line.rstrip('\n') for line in module_fh]
module_list.insert(0,'switch_mod')

model = utilities.define_AbstractModel(*module_list)

print "model successfully created..."

print "loading inputs into model..."
instance = model.load_inputs(inputs_dir=inputs_dir)
print "inputs successfully loaded..."
      
def save_dat_files():

    ##############
    # RootNode.dat

    if not os.path.exists(os.path.join(inputs_dir, pysp_subdir)):
        os.makedirs(os.path.join(inputs_dir, pysp_subdir))
    # Touch the root node file
    open(os.path.join(inputs_dir, pysp_subdir, "RootNode.dat"), 'a').close()    
    dat_file = os.path.join(inputs_dir, pysp_subdir, "RootNode.dat")
    print "creating and saving {}...".format(dat_file)
    utilities.save_inputs_as_dat(
        model, instance, save_path=dat_file)
    
    #######################
    # ScenarioStructure.dat

    scen_file = os.path.join(inputs_dir, pysp_subdir, "ScenarioStructure.dat")
    print "creating and saving {}...".format(scen_file)

    with open(scen_file, "w") as f:
        # Data will be defined in a Node basis to avoid redundancies
        f.write("param ScenarioBasedData := False ;\n\n")
        
        f.write("set Stages :=")
        for st in stage_list:
            f.write(" {}".format(st))
        f.write(";\n\n")

        f.write("set Nodes := RootNode ")
        for s in scenario_list:
            f.write("\n    {}".format(s))
        f.write(";\n\n")

        f.write("param NodeStage := RootNode {}\n".format(stage_list[0]))
        for s in scenario_list:
            f.write("    {scen} {st}\n".format(scen=s,st=stage_list[1]))
        f.write(";\n\n")
        
        f.write("set Children[RootNode] := ")
        for s in scenario_list:
            f.write("\n    {}".format(s))
        f.write(";\n\n")
    
        f.write("param ConditionalProbability := RootNode 1.0")
        # All scenarios have the same probability in this example
        probs = [1.0/len(scenario_list)] * (len(scenario_list) - 1)
        # The remaining probability is lumped in the last scenario to avoid rounding issues
        probs.append(1.0 - sum(probs))
        for (s, p) in zip(scenario_list, probs):
            f.write("\n    {s} {p}".format(s=s, p=p))
        f.write(";\n\n")

        f.write("set Scenarios :=  ")
        for s in scenario_list:
            f.write("\n    Scenario_{}".format(s))
        f.write(";\n\n")

        f.write("param ScenarioLeafNode := ")
        for s in scenario_list:
            f.write("\n    Scenario_{s} {s}".format(s=s, p=p))
        f.write(";\n\n")

        def write_var_name(f, cname):
            if hasattr(instance, cname):
                dimen = getattr(instance, cname).index_set().dimen
                indexing = "" if dimen == 0 else (",".join(["*"]*dimen))
                f.write("    {cn}[{dim}]\n".format(cn=cname, dim=indexing))

        # All build variables go in the Investment stage
        f.write("set StageVariables[{}] := \n".format(stage_list[0]))
        for cn in build_vars:
            write_var_name(f, cn)
        f.write(";\n\n")
        
        # All operations variables go in the Operation stage
        f.write("set StageVariables[{}] := \n".format(stage_list[1]))
        for cn in operate_vars:
            write_var_name(f, cn)
        f.write(";\n\n")

        f.write("param StageCostVariable := \n")
        f.write("    {s} {s}Cost\n".format(s=stage_list[0]))
        f.write("    {s} {s}Cost\n".format(s=stage_list[1]))
        f.write(";")

####################
    
if __name__ == '__main__':
    # If the script is executed on the command line, then the .dat files are created.
    save_dat_files()
