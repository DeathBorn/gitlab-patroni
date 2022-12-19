# frozen_string_literal: true

name             'gitlab-patroni'
maintainer       'GitLab Inc.'
maintainer_email 'ops-contact+cookbooks@gitlab.com'
license          'MIT'
description      'Installs and configures Patroni for GitLab'
version          '1.4.44'
chef_version     '>= 12.1'
issues_url       'https://gitlab.com/gitlab-cookbooks/gitlab-patroni/issues'
source_url       'https://gitlab.com/gitlab-cookbooks/gitlab-patroni'

supports 'ubuntu', '= 16.04'

depends 'poise-python', '~> 1.7.0'
depends 'poise-service', '~> 1.5.2'
depends 'logrotate', '~> 2.2.0'
depends 'gitlab_secrets'
depends 'consul', '~> 4.0'
depends 'nssm', '~> 4.0'
