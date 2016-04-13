import csv
import operator

localTD = csv.reader(open('outputs/BuildLocalTD.tab'), delimiter= '	')
localTDhead = localTD.next()
sort = sorted(localTD, key=operator.itemgetter(0,1))
of = csv.writer(open('outputs/BuildLocalTDSorted.tab','wb'), delimiter='	')
of.writerow(localTDhead)
for row in sort:
	of.writerow(row)

buildproj = csv.reader(open('outputs/BuildProj.tab'), delimiter= '	')
buildprojhead = buildproj.next()
sort = sorted(buildproj, key=operator.itemgetter(0,1))
of = csv.writer(open('outputs/BuildProjSorted.tab','wb'), delimiter='	')
of.writerow(buildprojhead)
for row in sort:
	of.writerow(row)

buildtrans = csv.reader(open('outputs/BuildTrans.tab'), delimiter= '	')
buildtranshead = buildtrans.next()
sort = sorted(buildtrans, key=operator.itemgetter(0,1))
of = csv.writer(open('outputs/BuildTransSorted.tab','wb'), delimiter='	')
of.writerow(buildtranshead)
for row in sort:
	of.writerow(row)

dispatchproj = csv.reader(open('outputs/DispatchProj.tab'), delimiter= '	')
dispatchprojhead = dispatchproj.next()
sort = sorted(dispatchproj, key=operator.itemgetter(0,1))
of = csv.writer(open('outputs/DispatchProjSorted.tab','wb'), delimiter='	')
of.writerow(dispatchprojhead)
for row in sort:
	of.writerow(row)

dispatchtrans = csv.reader(open('outputs/DispatchTrans.tab'), delimiter= '	')
dispatchtranshead = dispatchtrans.next()
sort = sorted(dispatchtrans, key=operator.itemgetter(0,1))
of = csv.writer(open('outputs/DispatchTransSorted.tab','wb'), delimiter='	')
of.writerow(dispatchtranshead)
for row in sort:
	of.writerow(row)