# -*- coding:utf-8 -*-
#!/usr/bin/env python

import argparse, requests
import sys, string, time
from xml.parsers.expat import ParserCreate
try:
    import json
except:
    import simplejson as json

cmdFileMode = 'cmd file mode'
cmdInteractMode = 'cmd interaction mode'


specialArgs = ['host']
commonArgs = ['add_upstream']
HOST = None

def doSpecArg(kvCmd):
    key = kvCmd[0].strip()
    val = kvCmd[1].strip()

    if str.upper(key) == 'HOST':
        global HOST
        HOST = val

def parseCmdFile(filename):
    f = open(filename)
    # error handle

    cmds = []
    lineN = 0
    for line in f.readlines():
        lineN   = lineN + 1
        line    = line.strip()
        if line == '' or line[0] == '*':
            continue

        kvCmd = line.split(':', 1)
        if len(kvCmd) < 2:
            print 'cmd error for invalid number of args in line NO. ' + str(lineN)
            sys.exit()
        
        if kvCmd[0] in specialArgs:
            doSpecArg(kvCmd)
        else:
            if not HOST:
                print 'HOST is not assigned'
                sys.exit()

            cmdname = kvCmd[0]
            cmdmod  = __import__('command')

            cmdclass = getattr(cmdmod, cmdname)
            cmdobj = cmdclass(HOST, kvCmd[1])
            valid, err = cmdobj.check()
            if not valid:
                hint = 'cmd [' + line + '] invalid in line No. ' + str(lineN)
                if err:
                    hint += ' : reason is ' + err
                print hint
                sys.exit()

            cmds.append(cmdobj)
    return cmds

def doCmdFile(filename):

    cmds = parseCmdFile(filename)

    if not cmds or type(cmds) != list or len(cmds) < 1:
        print 'parse cmd file' , filename , 'error, please check the file'
        sys.exit()
    print '\033[1;34;40m'
    print 'Your cmds are listed below:'
    for cmdobj in cmds:
        print '\033[1;32;40m'
        print 'No.', cmds.index(cmdobj), 'cmd:', cmdobj.cmd['action']
        print '\033[1;34;40m'
        cmdobj.echo()
    print '\033[0m'

    print '\n************************************************'
    while(True):
        c = raw_input('Are cmds correct? If correct they will be executed immediately[Y/N]')
        if c == '' or c == 'y' or c == 'Y':
            break
        else:
            print 'terminate this program and edit your cmd file again'
            sys.exit()

    print '\n************************************************'
    for cmdobj in cmds:
        print '\033[1;32;40m'
        print '------------------cmd------------------'
        print '\033[1;33;40m'
        cmdobj.echo()

        ret = cmdobj.run()
        print '\033[1;34;40m'
        print '-----------------result-----------------\n'
        print json.dumps(ret, indent = 1)

        print '\033[1;31;40m'
        print '------------------end------------------'

        c = raw_input('\nIs the result correct? If correct it will be continued[Y/N]')
        if c == '' or c == 'y' or c == 'Y':
            pass
        else:
            print 'terminate this program and edit your cmd file again'
            sys.exit()
        print '\033[0m'


def doCmdInteract():
    pass

if __name__ == '__main__':

    parser = argparse.ArgumentParser(description='dygateway cmd utility')
    parser.add_argument('-s', action="store", dest="filename")
    result = parser.parse_args(sys.argv[1:])

    if result.filename:
        print cmdFileMode
        print '\n************************************************'

        doCmdFile(result.filename)

    else:
        print cmdInteractMode

    
### todo list
# checkPort() exception handle
# file.readlines() 会有中间为空的元素吗

### acknowledge
# python 参数处理
# python 异常处理 &　主动异常
# python list
# python dict
# python file.readline
# python str is or not null
# python input and rawinput
# python 控制终端颜色
# python upper case and lower case convert

### know issues
# dyupsc模块需要有一定时间让各个work能够同步upstream信息
# ab模块的runtime_set无法获得policy_set(添加策略)返回的policyid，需要进一步的商量
