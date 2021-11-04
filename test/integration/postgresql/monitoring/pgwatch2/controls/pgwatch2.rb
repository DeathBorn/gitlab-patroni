if os.release.to_i < 18
  puts %q(This test doesn't support Ubuntu versions older than 18.04.)
  return
end

control 'Pgwatch2 configuration' do
  title 'Verify correctness'

  describe service('pgwatch2') do
    it { should be_installed }
    it { should be_enabled }
    it { should be_running }
  end

  describe file('/etc/pgwatch2/config/instances.yaml') do
    its('content') { should match(/unique_name: gitlabhq_production/) }
    its('content') { should match(/dbtype: postgres/) }
    its('content') { should match(/dbname: gitlabhq_production/) }
    its('content') { should match(/host: 127.0.0.1/) }
    its('content') { should match(/port: 5432/) }
    its('content') { should match(/username: gitlab-superuser/) }
    its('content') { should match(/password: superuser-password/) }
    its('content') { should match(/sslmode: disable/) }
    its('content') { should match(/stmt_timeout: 10/) }
    its('content') { should match(/preset_metrics: exhaustive/) }
    its('content') { should match(/dbname_include_pattern: gitlabhq_production/) }
    its('content') { should match(/is_enabled: true/) }
    its('content') { should match(/group: gitlabhq_production/) }
  end

  describe file('/etc/systemd/system/pgwatch2.service') do
    its('content') { should match(%r{/usr/bin/pgwatch2-daemon -c /etc/pgwatch2/config/instances.yaml}) }
    its('content') { should match(%r{-m /etc/pgwatch2/metrics}) }
    its('content') { should match(/--datastore=prometheus/) }
    its('content') { should match(/--prometheus-port=9187/) }
    its('content') { should match(/--prometheus-namespace=pgwatch2/) }
  end

  describe command('netstat -tulpn | grep LISTEN') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(%r{9187.+LISTEN\s+\d+/pgwatch2}) }
  end

  describe command('curl -v 127.0.0.1:9187') do
    its('exit_status') { should eq 0 }
    its('stderr') { should match(/HTTP.+200\s+OK/) }
    its('stdout') { should match(/go_gc_duration_seconds/) }
  end

  describe command('ls -al /etc/pgwatch2/metrics') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/archiver_pending_count/) }
  end
end
