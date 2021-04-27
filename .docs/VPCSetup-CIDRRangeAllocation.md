# VPC Setup and CIDR Range Allocation 

## 65536 IP’s in CIDR 10.10.0.0/16 are split into 8 VPC’s of 8192 as below  

1.  10.10.0.0/19 Stagging
2.  10.10.32.0/19 Devtools
3.  10.10.64.0/19 Devops
4.  10.10.96.0/19 QA
5.  10.10.128.0/19 Production
6.  10.10.160.0/19 future-purpose 
7.  10.10.192.0/19 future-purpose
8.  10.10.224.0/19 future-purpose

## Each VPC 8192 is split into 8 more subnets of 1024 IP each  

1.  SubnetPublic1
2.  SubnetPublic2
3.  SubnetPublic3
4.  SubnetPrivate1
5.  SubnetPrivate2
6.  SubnetPrivate3
7.  PublicStatic
8.  future-purpose


### If more IP's are required VPC can be extended by adding secondary CIDR
