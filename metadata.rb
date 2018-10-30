name             'gitlab-patroni'
maintainer       'GitLab Inc.'
maintainer_email 'ops-contact+cookbooks@gitlab.com'
license          'MIT'
description      'Installs and configures Patroni for GitLab'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.0.1'
chef_version     '>= 12.1' if respond_to?(:chef_version)
issues_url       'https://gitlab.com/gitlab-cookbooks/gitlab-patroni/issues'
source_url       'https://gitlab.com/gitlab-cookbooks/gitlab-patroni'

supports 'ubuntu', '= 16.04'

depends 'poise-python'
depends 'poise-service'
depends 'gitlab_secrets'
