default['gitlab-patroni']['user'] = 'postgres'
default['gitlab-patroni']['group'] = 'postgres'

default['gitlab-patroni']['secrets']['backend'] = 'dummy'
default['gitlab-patroni']['secrets']['path']['path'] = 'gitlab-gstg-secrets/gitlab-patroni'
default['gitlab-patroni']['secrets']['path']['item'] = 'gstg.enc'
default['gitlab-patroni']['secrets']['key']['ring'] = 'gitlab-secrets'
default['gitlab-patroni']['secrets']['key']['key'] = 'gstg'
default['gitlab-patroni']['secrets']['key']['location'] = 'global'

default['gitlab-patroni']['postgresql']['version'] = '9.6'
default['gitlab-patroni']['postgresql']['config_directory'] = '/var/opt/gitlab/postgresql'
default['gitlab-patroni']['postgresql']['data_directory'] = '/var/opt/gitlab/postgresql/data'
default['gitlab-patroni']['postgresql']['log_directory'] = '/var/log/gitlab/postgresql'
default['gitlab-patroni']['postgresql']['bin_directory'] = '/usr/lib/postgresql/9.6/bin'
default['gitlab-patroni']['postgresql']['listen_address'] = '0.0.0.0:5433'
default['gitlab-patroni']['postgresql']['ssl_ca'] = 'in vault'
default['gitlab-patroni']['postgresql']['ssl_cert'] = 'in vault'
default['gitlab-patroni']['postgresql']['ssl_key'] = 'in vault'
default['gitlab-patroni']['postgresql']['parameters']['port'] = 5433
default['gitlab-patroni']['postgresql']['parameters']['ssl'] = 'off'
default['gitlab-patroni']['postgresql']['parameters']['ssl_ciphers'] = 'HIGH:MEDIUM:+3DES:!aNULL:!SSLv3:!TLSv1'
default['gitlab-patroni']['postgresql']['parameters']['log_destination'] = 'syslog'

default['gitlab-patroni']['patroni']['version'] = '1.5.0'
default['gitlab-patroni']['patroni']['python_runtime_version'] = '3'
default['gitlab-patroni']['patroni']['pip_version'] = '18.0'
default['gitlab-patroni']['patroni']['config_directory'] = '/var/opt/gitlab/patroni'
default['gitlab-patroni']['patroni']['install_directory'] = '/opt/patroni'
default['gitlab-patroni']['patroni']['log_directory'] = '/var/log/gitlab/patroni'
default['gitlab-patroni']['patroni']['bind_interface'] = 'lo'

default['gitlab-patroni']['patroni']['users']['superuser']['username'] = 'gitlab-superuser'
default['gitlab-patroni']['patroni']['users']['superuser']['password'] = 'in-vault'
default['gitlab-patroni']['patroni']['users']['superuser']['options'] = %w[createrole createdb]
default['gitlab-patroni']['patroni']['users']['replication']['username'] = 'gitlab-replicator'
default['gitlab-patroni']['patroni']['users']['replication']['password'] = 'in-vault'
default['gitlab-patroni']['patroni']['users']['replication']['options'] = %w[replication]

default['gitlab-patroni']['patroni']['config']['scope'] = 'pg-ha-cluster'
default['gitlab-patroni']['patroni']['config']['name'] = node.name
default['gitlab-patroni']['patroni']['config']['restapi']['listen'] = '0.0.0.0:8009'
default['gitlab-patroni']['patroni']['config']['consul']['host'] = '127.0.0.1:8500'

default['gitlab-patroni']['patroni']['config']['bootstrap']['dcs']['ttl'] = 30
default['gitlab-patroni']['patroni']['config']['bootstrap']['dcs']['loop_wait'] = 10
default['gitlab-patroni']['patroni']['config']['bootstrap']['dcs']['retry_timeout'] = 10
default['gitlab-patroni']['patroni']['config']['bootstrap']['dcs']['maximum_lag_on_failover'] = 1_048_576
default['gitlab-patroni']['patroni']['config']['bootstrap']['dcs']['postgresql']['use_pg_rewind'] = true
default['gitlab-patroni']['patroni']['config']['bootstrap']['dcs']['postgresql']['use_slots'] = true
default['gitlab-patroni']['patroni']['config']['bootstrap']['dcs']['postgresql']['parameters']['wal_level'] = 'replica'
default['gitlab-patroni']['patroni']['config']['bootstrap']['dcs']['postgresql']['parameters']['hot_standby'] = 'on'
default['gitlab-patroni']['patroni']['config']['bootstrap']['dcs']['postgresql']['parameters']['wal_keep_segments'] = 8
default['gitlab-patroni']['patroni']['config']['bootstrap']['dcs']['postgresql']['parameters']['max_wal_senders'] = 5
default['gitlab-patroni']['patroni']['config']['bootstrap']['dcs']['postgresql']['parameters']['max_replication_slots'] = 5
default['gitlab-patroni']['patroni']['config']['bootstrap']['dcs']['postgresql']['parameters']['checkpoint_timeout'] = 30
default['gitlab-patroni']['patroni']['config']['bootstrap']['initdb'] = [{ 'encoding' => 'UTF8' }, { 'locale' => 'C.UTF-8' }]
default['gitlab-patroni']['patroni']['config']['bootstrap']['pg_hba'] = [
  # 'host postgres gitlab-superuser 192.168.0.0/11 md5',
  # 'host all gitlab-superuser 192.168.0.0/11 md5',
  # 'host all gitlab-superuser 192.168.0.0/11 md5',
  # 'host all gitlab-superuser 127.0.0.1/32 md5',
  # 'host replication gitlab-replicator 127.0.0.1/32 md5',
  # 'host replication gitlab-replicator 192.168.0.0/11 md5',
]
