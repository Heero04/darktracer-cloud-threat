import json
import boto3
import os
from datetime import datetime
import base64
import gzip
import ipaddress

# Initialize AWS clients
waf_client = boto3.client('wafv2')
sns_client = boto3.client('sns')
ec2_client = boto3.client('ec2')

def handler(event, context):
    try:
        if 'awslogs' in event:
            compressed_payload = base64.b64decode(event['awslogs']['data'])
            uncompressed_payload = gzip.decompress(compressed_payload)
            log_data = json.loads(uncompressed_payload)
            
            for log_event in log_data['logEvents']:
                try:
                    honeypot_data = json.loads(log_event['message'])
                    src_host = honeypot_data.get('src_host')
                    dst_port = honeypot_data.get('dst_port')
                    
                    ip_set_update_success = update_ip_set(waf_client, src_host, os.environ.get('IP_SET_ID'))

                    print(f"Processing attack from {src_host} on port {dst_port}")
                    
                    # Get security group ID from environment
                    security_group_id = os.environ.get('SECURITY_GROUP_ID')
                    if not security_group_id:
                        print("WARNING: No security group ID provided in environment variables")
                    
                    # Close port if specified
                    port_closed = False
                    if dst_port and security_group_id:
                        print(f"Attempting to close port {dst_port}")
                        port_closed = close_port_in_security_group(security_group_id, dst_port)
                    
                        
                        # Prepare notification data
                        message_data = {
                            'timestamp': datetime.utcnow().isoformat(),
                            'ip_address': src_host,
                            'port_attacked': dst_port,
                            'attack_details': honeypot_data,
                            'actions_taken': {
                                'waf_blocked': ip_set_update_success,
                                'port_closed': bool(dst_port and port_closed)
                            }
                        }
                        
                        # Send notification
                        publish_to_sns(sns_client, message_data)
                        
                        # Log the details
                        print(f"Attack Details:")
                        print(f"Source IP: {src_host}")
                        print(f"Target Port: {dst_port}")
                        
                except json.JSONDecodeError:
                    continue
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Processing complete',
                'ips_processed': list(processed_ips)
            })
        }
            
    except Exception as e:
        print(f"Error in handler: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }

def update_ip_set(waf_client, ip_address, ip_set_id, scope='REGIONAL'):
    """Update WAF IP set with new malicious IP"""
    try:
        # Get current IP set - Update this name to match your Terraform
        response = waf_client.get_ip_set(
            Name=f"{os.environ.get('PROJECT_NAME', 'darktracer')}-blocked-ip-set-{os.environ.get('ENV', 'dev')}", # Match your Terraform name
            Scope=scope,
            Id=ip_set_id
        )
        
        # Add new IP if not already present
        addresses = response['IPSet']['Addresses']
        new_ip = f"{ip_address}/32"
        if new_ip not in addresses:
            addresses.append(new_ip)
            
            # Update IP set - Use same name here
            waf_client.update_ip_set(
                Name=f"{os.environ.get('PROJECT_NAME', 'darktracer')}-blocked-ip-set-{os.environ.get('ENV', 'dev')}", # Match your Terraform name
                Scope=scope,
                Id=ip_set_id,
                Addresses=addresses,
                LockToken=response['LockToken']
            )
            print(f"Successfully added IP {ip_address} to WAF blocklist")
            return True
        return False
    except Exception as e:
        print(f"Error updating WAF IP set: {str(e)}")
        return False


def close_port_in_security_group(security_group_id, port):
    try:
        response = ec2_client.describe_security_groups(GroupIds=[security_group_id])
        permissions = response['SecurityGroups'][0]['IpPermissions']

        revoke_permissions = []
        for perm in permissions:
            if (perm.get('FromPort') == int(port) and 
                perm.get('ToPort') == int(port) and 
                perm.get('IpProtocol') == 'tcp'):

                # Save the full permission to revoke it properly
                revoke_permissions.append(perm)

        if not revoke_permissions:
            print(f"No matching rule found for port {port} in security group {security_group_id}")
            return True

        ec2_client.revoke_security_group_ingress(
            GroupId=security_group_id,
            IpPermissions=revoke_permissions
        )
        print(f"Successfully closed port {port} in security group {security_group_id}")
        return True

    except Exception as e:
        print(f"Error closing port {port}: {str(e)}")
        return False



def publish_to_sns(sns_client, message_data):
    """Publish threat notification to SNS"""
    try:
        sns_client.publish(
            TopicArn=os.environ['SNS_TOPIC_ARN'],
            Subject='Security Alert - Attack Detected',
            Message=json.dumps(message_data, indent=2)
        )
        print("Successfully published SNS notification")
        return True
    except Exception as e:
        print(f"Error publishing to SNS: {str(e)}")
        return False
# New Code V3
def is_internal_ip(ip):
    """Check if IP is internal"""
    ip_obj = ipaddress.ip_address(ip)
    return any([
        ip_obj in ipaddress.ip_network('10.0.0.0/8'),
        ip_obj in ipaddress.ip_network('172.16.0.0/12'),
        ip_obj in ipaddress.ip_network('192.168.0.0/16')
    ])
