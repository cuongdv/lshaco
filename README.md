Todo
===
2. command to master
Bug
===
1. lsend, memory leak, if argument error, no free

###monitor###
1. one-time monitor
```
./shaco config_cmdcli.lua --command "monitor"
```
2. watch monitor
```
watch -d -n 2 "./shaco config_cmdcli.lua --command \"monitor\""
```
3. watch monitor and log
```
watch -d -n 2 "./shaco config_cmdcli.lua --command \"monitor\" |tee -a log.log"
tail -f log.log
```
4. log all monitor input and output
```
./shaco config_cmdcli.lua |tee -a log.log
```
