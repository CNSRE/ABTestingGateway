#!/usr/bin/python
# -*- coding:utf-8 -*-

import requests, string, time
from xml.parsers.expat import ParserCreate
try:
    import json
except:
    import simplejson as json

uri_ab = '/ab_admin'
uri_dyupsc = '/dyupsc_admin'

def checkStr(arg):
    if type(arg) == str:
        dat = arg.strip()
        if dat and dat != '':
            return True
    return False

def checkJson(arg):
    if type(arg) == str:
        dat = arg.strip()
        if dat and json.loads(dat):
            return True
    return False

def checkInteger(arg):
    num = int(arg)
    if num == None:
        return False
    return True

def checkPort(arg):
    num = int(arg)
    if not num or\
        num <= 1 or num >= 65536:
        return False
    return True


def checkServerList(arg):
    arg = arg.strip()
    srvlist = arg.split(';')
    for srv in srvlist:
        if srv.strip() == '':
            continue
        items = srv.split()
        if 'server' not in items:
            return False
    return True

def checkBool(arg):
    if arg and type(arg) == str:
        arg = arg.lower()
        if arg == 'false' or \
                arg == 'true':
                    return True
    return False

class add_upstream:
    def __init__(self, host, cmdline):
        self.host = host
        self.url = 'http://'+ host + uri_dyupsc
        self.cmdline = cmdline
        self.cmd = {}
        self.cmd['action'] = 'add_upstream'

    def check(self):
        cmdline = self.cmdline.strip()
        args = cmdline.split('|')

        upstream = args[0]
        if not checkStr(upstream):
            return False, '1st arg: upstream error'

        servers  = args[1]
        if not checkStr(servers):
            return False, '2ed arg: servers error'

        self.cmd['upstream'] = upstream.strip()
        self.cmd['servers'] = servers.strip()
        return True, None

    def echo(self):
        print json.dumps(self.cmd, indent=1)

    def run(self):
        req = self.url + '?action=add_upstream'
        req += '&' + 'upstream=' + self.cmd['upstream']
        req += '&' + 'servers='  + self.cmd['servers']
        r = requests.get(req)
        time.sleep(2)
        return r.json()


class del_upstream:
    def __init__(self, host, cmdline):
        self.host = host
        self.url = 'http://'+ host + uri_dyupsc
        self.cmdline = cmdline
        self.cmd = {}
        self.cmd['action'] = 'del_upstream'

    def check(self):
        cmdline = self.cmdline.strip()
        args = cmdline.split('|')

        upstream = args[0]
        if not checkStr(upstream):
            return False, '1st arg: upstream error'

        self.cmd['upstream'] = upstream.strip()
        return True, None

    def echo(self):
        print json.dumps(self.cmd, indent=1)

    def run(self):
        req = self.url + '?action=remove_upstream'
        req += '&' + 'upstream=' + self.cmd['upstream']
        r = requests.get(req)

        time.sleep(1)

        return r.json()


class get_upstream:
    def __init__(self, host, cmdline):
        self.host = host
        self.url = 'http://'+ host + uri_dyupsc
        self.cmdline = cmdline
        self.cmd = {}
        self.cmd['action'] = 'get_upstream'

    def check(self):
        return True, None

    def echo(self):
        print json.dumps(self.cmd, indent=1)

    def run(self):
        req = self.url
        req += '?action=get_upstreams'
        r = requests.get(req)
        return r.json()

class add_member:
    def __init__(self, host, cmdline):
        self.host = host
        self.url = 'http://'+ host + uri_dyupsc
        self.cmdline = cmdline
        self.cmd = {}
        self.cmd['action'] = 'add_member'

    def check(self):
        cmdline = self.cmdline.strip()
        args = cmdline.split('|')

        if(len(args) < 6):
            return False, 'num of args is less than 6'

        upstream = args[0]
        if not checkStr(upstream):
            return False, '1st arg: upstream error'

        host  = args[1]
        if not checkStr(host):
            return False, '2ed arg: member host error'

        port  = args[2]
        if not checkPort(port):
            return False, '3rd arg: member port error'

        weight  = args[3]
        if not checkInteger(weight):
            return False, '4th arg: member weight error'

        maxfails  = args[4]
        if not checkInteger(maxfails):
            return False, '5th arg: member maxfails error'

        failtimeout  = args[5]
        if not checkInteger(failtimeout):
            return False, '5th arg: member failtimeout error'

        cmd = self.cmd
        cmd['upstream'] = upstream.strip()
        cmd['host'] = host.strip() 
        cmd['port'] = port.strip()           
        cmd['weight'] = weight.strip()
        cmd['maxfails'] = maxfails.strip()
        cmd['failtimeout'] = failtimeout.strip()
        return True, None

    def echo(self):
        print json.dumps(self.cmd, indent=1)

    def run(self):
        
#        str = "".join(['&%s=%s' % (key, self.cmd[key]) for key in self.cmd])
        cmd = self.cmd
        req = self.url  + '?action='    + 'add_server'   +   \
                          '&upstream='  + cmd['upstream']+   \
                          '&port='      + cmd['port']    +   \
                          '&ip='        + cmd['host']    +   \
                          '&weight='    + cmd['weight']  +   \
                          '&maxfails='  + cmd['maxfails']+   \
                          '&failtimeout=' + cmd['failtimeout']

        print req
        time.sleep(2)
                    
        r = requests.get(req)
        ret = r.json()
        code = ret['code']
        if code != 200:
            return r.json()

        req = self.url  + '?action='    + 'add_peer'   +   \
                          '&upstream='  + cmd['upstream']+   \
                          '&port='      + cmd['port']    +   \
                          '&ip='        + cmd['host']

        print req
        r = requests.get(req)
        time.sleep(1)
        return r.json()

class get_member:
    def __init__(self, host, cmdline):
        self.host = host
        self.url = 'http://'+ host + uri_dyupsc
        self.cmdline = cmdline
        self.cmd = {}
        self.cmd['action'] = 'get_member'

    def check(self):
        return True, None

    def echo(self):
        print json.dumps(self.cmd, indent=1)

    def run(self):
        req = self.url + '?action=get_primary_peers'
        r = requests.get(req)
        ret = r.json()
        code = ret['code']
        members = ret['data'] 
        if code != 200:
            return r.json()

#       发现backup_peers被删掉，仍然会被backup返回
        req = self.url + '?action=get_backup_peers'
        r = requests.get(req)
        ret = r.json()
        code = ret['code']
        if code != 200:
            return r.json()

        backup = ret['data']
        for ups in backup:
            if len(backup[ups]) > 0:
                if members[ups]:
                    for item in backup[ups]:
                        item['state'] = 'backup'
                        members[ups].append(item)
        return members

class del_member:
    def __init__(self, host, cmdline):
        self.host = host
        self.url = 'http://'+ host + uri_dyupsc
        self.cmdline = cmdline
        self.cmd = {}
        self.cmd['action'] = 'del_member'

    def check(self):
        cmdline = self.cmdline.strip()
        args = cmdline.split('|')

        if(len(args) < 3):
            return False, 'num of args is less than 6'

        upstream = args[0]
        if not checkStr(upstream):
            return False, '1st arg: upstream error'

        host  = args[1]
        if not checkStr(host):
            return False, '2ed arg: member host error'

        port  = args[2]
        if not checkPort(port):
            return False, '3rd arg: member port error'

        cmd = self.cmd
        cmd['upstream'] = upstream.strip()
        cmd['host'] = host.strip() 
        cmd['port'] = port.strip()           

        return True, None

    def echo(self):
        print json.dumps(self.cmd, indent=1)

    def run(self):

        cmd = self.cmd
        req = self.url  + '?action='    + 'remove_peer'   +   \
                          '&upstream='  + cmd['upstream']+   \
                          '&port='      + cmd['port']    +   \
                          '&ip='        + cmd['host']

        r = requests.get(req)
        ret = r.json()
        code = ret['code']
        members = ret['data'] 
        if code != 200:
            return ret
        time.sleep(1)
        req = self.url  + '?action='    + 'remove_server'   +   \
                          '&upstream='  + cmd['upstream']+   \
                          '&port='      + cmd['port']    +   \
                          '&ip='        + cmd['host']

        r = requests.get(req)
        ret = r.json()
        code = ret['code']
        if code != 200:
            return ret
        members = ret['data'] 
        time.sleep(1)
        return members

class setup_member:
    def __init__(self, host, cmdline):
        self.host = host
        self.url = 'http://'+ host + uri_dyupsc
        self.cmdline = cmdline
        self.cmd = {}
        self.cmd['action'] = 'setup_member'

    def check(self):
        cmdline = self.cmdline.strip()
        cmd  = self.cmd
        args = cmdline.split('|')

        if(len(args) < 3):
            return False, 'num of args is at least 3'

        upstream = args[0]
        if not checkStr(upstream):
            return False, '1st arg: upstream error'

        mid  = args[1]
        if not checkInteger(mid):
            return False, '2ed arg: member id error'

        for item in args[2:]:
            kv = item.split('=')
            if len(kv) != 2:
                return False, 'arg '+ item +' invalid'
            key = kv[0].strip()
            val = kv[1].strip()
            if key not in ['weight', 'max_fails', 'fail_timeout']:
                return False, 'arg '+ item + ':'+key+' not supported'
            cmd[key]=val

        cmd['upstream'] = upstream.strip()
        cmd['id'] = mid.strip() 

        return True, None

    def echo(self):
        print json.dumps(self.cmd, indent=1)

    def run(self):

        cmd = self.cmd
        baseurl = self.url + '?upstream='  + cmd['upstream']+   \
                             '&id='        + cmd['id'] +\
                             '&backup=false'
        if cmd['weight']:
            req = baseurl
            req += '&action=' + 'set_peer_weight' 
            req += '&value=' + cmd['weight']
            print req
            r = requests.get(req)
            ret = r.json()
            code = ret['code']
            if code != 200:
                return ret
        time.sleep(1)

        if cmd['max_fails']:
            req = baseurl
            req += '&action=' + 'set_peer_max_fails' 
            req += '&value=' + cmd['max_fails']
            print req
            r = requests.get(req)
            ret = r.json()
            code = ret['code']
            if code != 200:
                return ret
        time.sleep(1)

        if cmd['fail_timeout']:
            req = baseurl
            req += '&action=' + 'set_peer_fail_timeout' 
            req += '&value=' + cmd['fail_timeout']
            print req
            r = requests.get(req)
            ret = r.json()
            code = ret['code']
            if code != 200:
                return ret
        time.sleep(1)
        return ret


class add_policy:
    def __init__(self, host, cmdline):
        self.host = host
        self.url = 'http://'+ host + uri_ab
        self.cmdline = cmdline
        self.cmd = {}
        self.cmd['action'] = 'policygroup_set'
        self.policies = []

    def check(self):
        cmdline = self.cmdline.strip()
        cmd  = self.cmd
        args = cmdline.split('|')

        if(len(args) < 1):
            return False, 'at least 1 policygroup is needed'

        for idx, policy in enumerate(args):
            if not checkJson(policy):
                return False, 'policygroup ['+ policy +'] index ['+ str(idx) +'] invalid'
            self.policies.append(policy)

        return True, None

    def echo(self):
        print 'action = add_policy'
        for idx, policy in enumerate(self.policies):
            print '******policy ', idx, ' ******'
            print json.dumps(policy, indent=1)
            print '**********************'

    def run(self):

        cmd = self.cmd
        baseurl = self.url + '?action=' + cmd['action']

        for policy in self.policies:
            r = requests.post(baseurl, data = policy)
            ret = r.json()
            code = ret['code']
            print json.dumps(r.json(), indent=1)
            if code != 200:
                return ret

        return r.json()


class get_policy:
    def __init__(self, host, cmdline):
        self.host = host
        self.url = 'http://'+ host + uri_ab
        self.cmdline = cmdline
        self.cmd = {}
        self.cmd['action'] = 'policygroup_get'
        self.policygroups = []

    def check(self):
        cmdline = self.cmdline.strip()
        cmd  = self.cmd
        args = cmdline.split('|')

        if(len(args) < 1):
            return False, 'at least 1 policygroup_id is needed'

        for idx, pid in enumerate(args):
            if not checkInteger(pid):
                return False, 'policygroup_id ['+ pid +'] index ['+ str(idx) +'] invalid'
            self.policygroups.append(pid.strip())

        return True, None

    def echo(self):
        print 'action = get_policy'
        print 'all the id of policygroups are ', self.policygroups

    def run(self):

        cmd = self.cmd
        baseurl = self.url

        policygroups = {} # result
        for pgid in self.policygroups: # pgid list
            req = baseurl + '?action=' + cmd['action']+ '&policygroupid='+pgid
            r = requests.get(req)
            ret = r.json()
            code = ret['code']
            if code != 200:
                return ret

            policygroup = {}

            policies = []
            pidlist = ret['data']['group']
            for idx, pid in enumerate(pidlist):
                req = baseurl + '?action=policy_get&policyid='+pid
                r = requests.get(req)
                ret = r.json()

                policy = {}
                if ret['code'] == 200:
                    policy = ret['data']

                policy['policy_id'] = pid
                pkey = 'step = <'+ str(idx) +'>'
                policygroup[pkey] = policy

            pgkey = 'policygroup_id = ['+pgid+']'
            policygroups[pgkey] = policygroup

        return policygroups


class del_policy:
    def __init__(self, host, cmdline):
        self.host = host
        self.url = 'http://'+ host + uri_ab
        self.cmdline = cmdline
        self.cmd = {}
        self.cmd['action'] = 'policygroup_del'
        self.policygroups = []

    def check(self):
        cmdline = self.cmdline.strip()
        cmd  = self.cmd
        args = cmdline.split('|')

        if(len(args) < 1):
            return False, 'at least 1 policygroup_id is needed'

        for idx, pid in enumerate(args):
            if not checkInteger(pid):
                return False, 'policygroup_id ['+ pid +'] index ['+ str(idx) +'] invalid'
            self.policygroups.append(pid.strip())

        return True, None

    def echo(self):
        print 'action = del_policy'
        print 'all the id of policygroups are ', self.policygroups

    def run(self):

        cmd = self.cmd
        baseurl = self.url+ '?action=' + cmd['action']

        policygroups = {} # result
        for pgid in self.policygroups: # pgid list
            req = baseurl + '&policygroupid='+pgid
            r = requests.get(req)
            ret = r.json()
            code = ret['code']
            if code != 200:
                return ret
        return ret

class get_runtime:
    def __init__(self, host, cmdline):
        self.host = host
        self.url = 'http://'+ host + uri_ab
        self.cmdline = cmdline
        self.cmd = {}
        self.cmd['action'] = 'runtime_get'
        self.hostnames = []

    def check(self):
        cmdline = self.cmdline.strip()
        args = cmdline.split('|')

        if(len(args) < 1):
            return False, 'at least 1 hostname is needed'

        for idx, hostname in enumerate(args):
            if not checkStr(hostname):
                return False, 'hostname ['+ hostname +'] index ['+ str(idx) +'] invalid'
            self.hostnames.append(hostname.strip())

        return True, None

    def echo(self):
        print 'action = get_runtime'
        print 'all the hostnames are ', self.hostnames

    def run(self):

        baseurl = self.url+ '?action=' + self.cmd['action']
        runtimes = {}
        for hostname in self.hostnames: # pgid list
            req = baseurl + '&hostname='+ hostname
            r = requests.get(req)
            ret = r.json()
            code = ret['code']
            if code != 200:
                return ret

            runtime = ret['data']
            rkey = '<'+hostname+'>'
            runtimes[rkey] = runtime
        return runtimes

class del_runtime:
    def __init__(self, host, cmdline):
        self.host = host
        self.url = 'http://'+ host + uri_ab
        self.cmdline = cmdline
        self.cmd = {}
        self.cmd['action'] = 'runtime_del'
        self.hostnames = []

    def check(self):
        cmdline = self.cmdline.strip()
        args = cmdline.split('|')

        if(len(args) < 1):
            return False, 'at least 1 hostname is needed'

        for idx, hostname in enumerate(args):
            if not checkStr(hostname):
                return False, 'hostname ['+ hostname +'] index ['+ str(idx) +'] invalid'
            self.hostnames.append(hostname.strip())

        return True, None

    def echo(self):
        print 'action = del_runtime'
        print 'all the hostnames are ', self.hostnames

    def run(self):

        baseurl = self.url+ '?action=' + self.cmd['action']
        runtimes = {}
        for hostname in self.hostnames: # pgid list
            req = baseurl + '&hostname='+ hostname
            r = requests.get(req)
            ret = r.json()
            code = ret['code']
            if code != 200:
                return ret
        return ret

class set_runtime:
    def __init__(self, host, cmdline):
        self.host = host
        self.url = 'http://'+ host + uri_ab
        self.cmdline = cmdline
        self.cmd = {}
        self.cmd['action'] = 'runtime_set'
        self.hostnames = {}

    def check(self):
        cmdline = self.cmdline.strip()
        args = cmdline.split('|')

        if(len(args) < 1):
            return False, 'at least 1 pair of <hostname:policyid> is needed'

        for idx, host_pid in enumerate(args):

            kv = host_pid.split('=')
            if len(kv) < 2:
                return False, 'arg '+ kv + ' invalid'
            host = kv[0].strip()
            pid  = kv[1].strip()

            if not checkStr(host):
                return False, 'hostname ['+ host +'] index ['+ str(idx) +'] invalid'
            if not checkInteger(pid):
                return False, 'policyid ['+ pid  +'] index ['+ str(idx) +'] invalid'
            self.hostnames[host] = pid

        return True, None

    def echo(self):
        print 'action = set_runtime'
        print 'all the hostnames are ', self.hostnames

    def run(self):

        baseurl = self.url+ '?action=' + self.cmd['action']
        runtimes = {}
        for host in self.hostnames: # pgid list
            req = baseurl + '&hostname='+ host + '&policygroupid=' + self.hostnames[host]
            r = requests.get(req)
            ret = r.json()
            code = ret['code']
            if code != 200:
                return ret
        return ret
