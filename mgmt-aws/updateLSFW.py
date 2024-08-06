#!/usr/bin/python3
import copy
import ipaddress

def cidrAddIfNotExist(CIDRSArray, CIDRSToAdd):
    """
    Mutate the <CIDRSArray>
      - Add the <CIDRSToAdd> if not existed yet

    IN cidrAddIfNotExist(['127.0.0.1/32'], "127.0.0.2/32")
    OUT ['127.0.0.1/32', '127.0.0.2/32']
    
    RETURN 0 if CIDRSArray is modified
    RETURN 1 if CIDRSArray is unchanged
    """
    x = ipaddress.IPv4Network(CIDRSToAdd)
    for n0 in CIDRSArray:
        # if exist, do nothing
        y = ipaddress.IPv4Network(n0)
        if x.subnet_of(y):
            if IS_DRY_RUN:
                print("cidrAddIfNotExist: match found, do noting")
            return 1;
    # not exist, add the string notion of the Network
    CIDRSArray.append(x.exploded)
    if IS_DRY_RUN:
       print("cidrAddIfNotExist:")
       print(x)
       print(n0)
       print(CIDRSArray)
    return 0;

def utilTransform(portStates):
    """
    IN portStates = get_instance_port_states(...)
    OUT put_instance_public_ports(portInfos=portStates, ...)
    """
    for i in portStates:
        i.pop('state', None)
    return portStates


def updateFWRules(CIDRSToAdd, LightsailInstanceName="", IS_DRY_RUN=True):
    import boto3

    # region_name defined in ~/.aws/config
    lsClient = boto3.client('lightsail')
    res = lsClient.get_instance_port_states(instanceName=LightsailInstanceName)
    portStatesPrev = res.get("portStates")
    if IS_DRY_RUN:
        print("old:")
        print(res)

    # Add CIDRSToAdd in SSH access
    # [{...}, {'fromPort': 22, 'toPort': 22, 'protocol': 'tcp', 'state': 'open', 'cidrs': ['127.0.0.1/32'], 'ipv6Cidrs': [], 'cidrListAliases': ['lightsail-connect']}]
    portStatesNew = copy.deepcopy(portStatesPrev)
    for r in portStatesNew:
        if r.get('toPort') == 22 and r.get('state') == 'open':
            cidrX = r.get('cidrs');
            cidrExisted = cidrAddIfNotExist(cidrX, CIDRSToAdd)
            if cidrExisted == 1:
                exit(0);
            r['cidrs'] = cidrX

    if IS_DRY_RUN:
        print("new:")
        print(portStatesNew)
    else:
        res = lsClient.put_instance_public_ports(portInfos = utilTransform(portStatesNew), instanceName=LightsailInstanceName)
        print(res)

def secIPTransform(externalIPString):
    try:
        # ipv4 (3*4+3) + subnet (3) + quote(2) == 20
        if len(externalIPString) > 20:
            raise(Exception("secIPTransform: illegal IP"))
        x = ipaddress.IPv4Network(externalIPString)
    except Exception as e:
        raise(e)
    return x
    
if __name__ == "__main__":
    import sys
    if len(sys.argv) < 2 or len(sys.argv) > 4:
        print("Usage: python3 <thisFile> <IPv4/CIDR> <LightsailInstanceName> [isDryRun]")
        exit(1)

    CIDRNew = sys.argv[1]
    NW0 = secIPTransform(CIDRNew)

    LS_INS_NAME = ""
    if len(sys.argv) > 2:
        LS_INS_NAME = str(sys.argv[2])

    IS_DRY_RUN = True
    if len(sys.argv) > 3:
        if str(sys.argv[3]).lower() in ["FALSE", "false", "False"]:
            IS_DRY_RUN = False
    updateFWRules(NW0.exploded, LS_INS_NAME, IS_DRY_RUN)

