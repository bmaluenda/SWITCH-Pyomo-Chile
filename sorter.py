import csv
import operator
import os

if os.path.exists('outputs/BuildLocalTD.tab'):
	localTD = csv.reader(open('outputs/BuildLocalTD.tab'), delimiter= '	')
	localTDhead = localTD.next()
	sort = sorted(localTD, key=operator.itemgetter(0,1))
	of = csv.writer(open('outputs/BuildLocalTD.tab','wb'), delimiter='	')
	of.writerow(localTDhead)
	for row in sort:
		of.writerow(row)

if os.path.exists('outputs/CommitProject.tab'):
	commits = csv.reader(open('outputs/CommitProject.tab'), delimiter= '	')
	commitshead = commits.next()
	sort = sorted(commits, key=operator.itemgetter(0,1))
	of = csv.writer(open('outputs/CommitProject.tab','wb'), delimiter='	')
	of.writerow(commitshead)
	for row in sort:
		of.writerow(row)

buildproj = csv.reader(open('outputs/BuildProj.tab'), delimiter= '	')
buildprojhead = buildproj.next()
sort = sorted(buildproj, key=operator.itemgetter(0,1))
of = csv.writer(open('outputs/BuildProj.tab','wb'), delimiter='	')
of.writerow(buildprojhead)
for row in sort:
	of.writerow(row)

buildtrans = csv.reader(open('outputs/BuildTrans.tab'), delimiter= '	')
buildtranshead = buildtrans.next()
sort = sorted(buildtrans, key=operator.itemgetter(0,1))
of = csv.writer(open('outputs/BuildTrans.tab','wb'), delimiter='	')
of.writerow(buildtranshead)
for row in sort:
	of.writerow(row)

dispatchproj = csv.reader(open('outputs/DispatchProj.tab'), delimiter= '	')
dispatchprojhead = dispatchproj.next()
sort = sorted(dispatchproj, key=operator.itemgetter(0,1))
of = csv.writer(open('outputs/DispatchProj.tab','wb'), delimiter='	')
of.writerow(dispatchprojhead)
for row in sort:
	of.writerow(row)

dispatchtrans = csv.reader(open('outputs/DispatchTrans.tab'), delimiter= '	')
dispatchtranshead = dispatchtrans.next()
sort = sorted(dispatchtrans, key=operator.itemgetter(0,1))
of = csv.writer(open('outputs/DispatchTrans.tab','wb'), delimiter='	')
of.writerow(dispatchtranshead)
for row in sort:
	of.writerow(row)

dumppower = csv.reader(open('outputs/DumpPower.tab'), delimiter= '	')
dumppowerhead = dumppower.next()
sort = sorted(dumppower, key=operator.itemgetter(0,1))
of = csv.writer(open('outputs/DumpPower.tab','wb'), delimiter='	')
of.writerow(dumppowerhead)
for row in sort:
	of.writerow(row)

projfuel = csv.reader(open('outputs/ProjFuelUseRate.tab'), delimiter= '	')
projfuelhead = projfuel.next()
sort = sorted(projfuel, key=operator.itemgetter(0,1,2))
of = csv.writer(open('outputs/ProjFuelUseRate.tab','wb'), delimiter='	')
of.writerow(projfuelhead)
for row in sort:
	of.writerow(row)

