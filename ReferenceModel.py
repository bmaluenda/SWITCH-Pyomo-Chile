#!/usr/bin/env python
"""Generate a model for use with the progressive hedging algorithm.

If loaded as a module by runph, this creates a "model" object which can be
used to define the model.

If called as a script, this creates ReferenceModel.dat in the inputs directory,
with all the data needed to instantiate the model.

This can also be loaded interactively to experiment with instantiating from the
ReferenceModel.dat file ("import ReferenceModel; ReferenceModel.load_dat_inputs()")
"""

# turn on universal exception debugging (on the runph side)
# import debug

# define data location and size
# NOTE: these are not used when the model is loaded by runph;
# they are only used when ReferenceModel is run as a script
# to create runph input files.
inputs_dir = "inputs"
pha_subdir = "pha_test"

build_vars = [
    "BuildProj"]

import sys, os, time, traceback

from pyomo.environ import *
from pyomo.opt import SolverFactory, SolverStatus, TerminationCondition

import switch_mod.utilities as utilities

# if imported by another module, just create the model (which will be extracted by the other module)
# if loaded directly with an output file argument, write the dat file

print "loading model..."

try:
    module_fh = open(os.path.join(inputs_dir, 'modules'), 'r')
except IOError, exc:
    sys.exit('Failed to open input file: {}'.format(exc))
module_list = [line.rstrip('\n') for line in module_fh]
module_list.insert(0,'switch_mod')

model = utilities.define_AbstractModel(*module_list)
instance = None

print "loading inputs..."
instance = model.load_inputs(inputs_dir=inputs_dir)

def load_dat_inputs():
    global instance
    # TODO: this needs to load from RootNode.dat and also a scenario file
    instance = model.create_instance(os.path.join(inputs_dir, pha_subdir, "RootNode.dat"))
        
def save_dat_files():
    if not os.path.exists(os.path.join(inputs_dir, pha_subdir)):
        os.makedirs(os.path.join(inputs_dir, pha_subdir))
    if not os.path.exists(os.path.join(inputs_dir, pha_subdir, "RootNode.dat")):
        open(os.path.join(inputs_dir, pha_subdir, "RootNode.dat"), 'a').close()
    dat_file = os.path.join(inputs_dir, pha_subdir, "RootNode.dat")
    print "saving {}...".format(dat_file)
    utilities.save_inputs_as_dat(
        model, instance, save_path=dat_file)

    try:
        scenario_fh = open(os.path.join(os.path.dirname(__file__), 'scenarios.txt'), 'r')
    except IOError, exc:
        sys.exit('Failed to open input file: {}'.format(exc))
    scenario_list = [line.rstrip('\n') for line in scenario_fh]
    #scenarios = [str(i).zfill(n_digits) for i in range(n_scenarios)]
    
    scen_file = os.path.join(inputs_dir, pha_subdir, "ScenarioStructure.dat")
    print "saving {}...".format(scen_file)
    with open(scen_file, "w") as f:
        # Data will be defined in a Node basis to avoid redundancies
        f.write("param ScenarioBasedData := False ;\n\n")
        
        f.write("set Stages := Investment Operation ;\n\n")

        f.write("set Nodes := RootNode ")
        for s in scenario_list:
            f.write("\n    {}".format(s))
        f.write(";\n\n")

        f.write("param NodeStage := RootNode Investment\n")
        for s in scenario_list:
            f.write("    {} Operation\n".format(s))
        f.write(";\n\n")
        
        f.write("set Children[RootNode] := ")
        for s in scenario_list:
            f.write("\n    {}".format(s))
        f.write(";\n\n")
    
        f.write("param ConditionalProbability := RootNode 1.0")
        probs = [1.0/len(scenario_list)] * (len(scenario_list) - 1)# evenly spread among all scenarios
        probs.append(1.0 - sum(probs))  # lump the remainder into the last scenario
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
        f.write("set StageVariables[Investment] := \n")
        for cn in build_vars:
            write_var_name(f, cn)
        f.write(";\n\n")
        
        # all other variables go in the Operate stage
        """
        operate_vars = [
            c.cname() for c in instance.component_objects() 
                if isinstance(c, pyomo.core.base.var.Var) and c.cname() not in build_vars
        ]
        """
        operate_vars = ["DispatchProj", "DumpPower"]
        f.write("set StageVariables[Operation] := \n")
        for cn in operate_vars:
            write_var_name(f, cn)
        f.write(";\n\n")

        f.write("param StageCostVariable := \n")
        f.write("    Investment InvestCost\n")
        f.write("    Operation OperateCost\n")
        f.write(";\n\n")
        # note: this uses dummy variables for now; if real values are needed,
        # it may be possible to construct them by extracting all objective terms that 
        # involve the Build variables.

def save_rho_file():
    print "calculating objective function coefficients for rho setters..."
    m = instance

    # Initialize variables as 0 value if they don't have an initial assignment
    for var in m.component_map(Var):
        for v in getattr(m, var).values():
            if v.value is None:
                # note: we're just using this to find d_objective / d_var,
                # so it doesn't need to be realistic or even within the allowed bounds
                # if the model is linear; 
                v.value = 0.0

    costs = []
    baseval = value(m.Minimize_System_Cost)
    # surprisingly slow, but it gets the job done
    for var in build_vars:
        print var
        for v in getattr(m, var).values():
            # perturb the value of each variable to find its coefficient in the objective function
            v.value += 1; c = value(m.Minimize_System_Cost) - baseval; v.value -= 1
            costs.append((v.cname(), c))
    rho_file = os.path.join(inputs_dir, "rhos.tsv")
    print "writing {}...".format(rho_file)
    with open(rho_file, "w") as f:
        f.writelines("\t".join(map(str, r))+"\n" for r in costs)
    
        
###############
    
if __name__ == '__main__':
    # This will execute when the script is called from the command line
    save_dat_files()
    save_rho_file()

import csv
import switch_mod.financials as fin
def calc_tp_costs_in_period(m, t):
        return sum(
            getattr(m, tp_cost)[t] * m.tp_weight_in_year[t]
            for tp_cost in m.cost_components_tp)

    # Note: multiply annual costs by a conversion factor if running this
    # model on an intentional subset of annual data whose weights do not
    # add up to a full year: sum(tp_weight_in_year) / hours_per_year
    # This would also require disabling the validate_time_weights check.
def calc_annual_costs_in_period(m, p):
        return sum(
            getattr(m, annual_cost)[p]
            for annual_cost in m.cost_components_annual)

#Finally, augment the model with stage costs as separate expressions for PySP

model.InvestCost = Expression(rule=lambda m: sum(calc_annual_costs_in_period(m, p) * fin.uniform_series_to_present_value(
                m.discount_rate, m.period_length_years[p]) * fin.future_to_present_value(
                m.discount_rate, (m.period_start[p] - m.base_financial_year)) for p in m.PERIODS))
model.OperateCost = Expression(rule=lambda m: sum(sum(calc_tp_costs_in_period(m, t) for t in m.PERIOD_TPS[p]) * fin.uniform_series_to_present_value(
                m.discount_rate, m.period_length_years[p]) * fin.future_to_present_value(
                m.discount_rate, (m.period_start[p] - m.base_financial_year)) for p in m.PERIODS))

"""
def ComputeFirstStageCost_rule(model):
    global instance
    FSCosts = 0
    for var in build_vars:
        for v in getattr(instance, var).values():
            with open(os.path.join(inputs_dir, "rhos.tsv")) as f:
                for line in csv.reader(f, delimiter="\t"):
                    if line[0] == v.cname():
                        FSCosts += v.value * float(line[1])                  
    return sum(fsc for fsc in FSCosts)
model.InvestCost = Expression(rule=ComputeFirstStageCost_rule)


def ComputeSecondStageCost_rule(model):    
    return model.Minimize_System_Cost.expr - model.InvestCost

model.OperateCost = Expression(rule=ComputeSecondStageCost_rule)
#print "----------------------------"
#print model.InvestCost.expr
#print model.OperateCost.expr
#print "----------------------------"
"""
# define upper and lower reduced costs to use when setting rho
# model.iis = Suffix(direction=Suffix.IMPORT)
if not hasattr(model, 'dual'):
    model.dual = Suffix(direction=Suffix.IMPORT)
model.urc = Suffix(direction=Suffix.IMPORT)
model.lrc = Suffix(direction=Suffix.IMPORT)
model.rc = Suffix(direction=Suffix.IMPORT)












def solve():
    if instance is None:
        raise RuntimeError("instance is not initialized; load_inputs() or load_dat_inputs() must be called before solve().")
    # can be accessed from interactive prompt via import ReferenceModel; ReferenceModel.solve()
    print "solving model..."
    opt = SolverFactory("cplex", solver_io="nl")
    # tell cplex to find an irreducible infeasible set (and report it)
    # opt.options['iisfind'] = 1

    # relax the integrality constraints, to allow commitment constraints to match up with 
    # number of units available
    # opt.options['mipgap'] = 0.001
    # # display more information during solve
    # opt.options['display'] = 1
    # opt.options['bardisplay'] = 1
    # opt.options['mipdisplay'] = 1
    # opt.options['primalopt'] = ""   # this is how you specify single-word arguments
    # opt.options['advance'] = 2
    # # opt.options['threads'] = 1
    # opt.options['parallelmode'] = -1    # 1=opportunistic, 0 or 1=deterministic

    start = time.time()
    results = opt.solve(instance, keepfiles=False, tee=True, 
        symbolic_solver_labels=True, suffixes=['dual', 'rc', 'urc', 'lrc'])
    print "Total time in solver: {t}s".format(t=time.time()-start)

    instance.solutions.load_from(results)

    if results.solver.termination_condition == TerminationCondition.infeasible:
        print "Model was infeasible; Irreducible Infeasible Set (IIS) returned by solver:"
        print "\n".join(c.cname() for c in instance.iis)
        raise RuntimeError("Infeasible model")

    print "\n\n======================================================="
    print "Solved model"
    print "======================================================="
    print "Total cost: ${v:,.0f}".format(v=value(instance.Minimize_System_Cost))