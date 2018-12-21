# Cookbook Name:: gitlab-patroni
# Recipe:: consul
# License:: MIT
#
# Copyright 2018, GitLab Inc.

service 'consul' do
  supports [:reload]
end

consul_definition 'patroni' do
  type 'services'
  parameters(
    [
      {
        id: 'patroni-master',
        name: 'patroni',
        tags: [
          'master'
        ],
        checks: [
          {
            http: "http://#{node['gitlab-patroni']['patroni']['config']['restapi']['listen']}/master",
            interval: '10s'
          }
        ].concat(node['gitlab-patroni']['patroni']['consul']['extra_checks'])
      },
      {
        id: 'patroni-replica',
        name: 'patroni',
        tags: [
          'replica'
        ],
        checks: [
          {
            http: "http://#{node['gitlab-patroni']['patroni']['config']['restapi']['listen']}/replica",
            interval: '10s'
          }
        ].concat(node['gitlab-patroni']['patroni']['consul']['extra_checks'])
      }
    ]
  )
  notifies :reload, 'service[consul]', :delayed
end
