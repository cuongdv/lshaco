package.path = package.path .. ";./?.lua;../3rdlib/?.lua"
package.cpath = package.cpath .. ";./?.so;../3rdlib/?.so"
print(package.path)
print(package.cpath)

