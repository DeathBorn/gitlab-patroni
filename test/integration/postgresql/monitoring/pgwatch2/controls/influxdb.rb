if os.release.to_i < 18
  log %q(This test doesn't support Ubuntu versions older than 18.04.)
  return
end

control 'InfluxDB configuration' do
  title 'Verify correctness'

  describe service('influxdb') do
    it { should be_installed }
    it { should be_enabled }
    it { should be_running }
  end

  describe command('influx -execute "SHOW DATABASES"') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/pgwatch2/) }
  end

  describe command('influx -execute "SHOW RETENTION POLICIES on pgwatch2"') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/^pgwatch2_def_ret\s+720h0m0s\s+24h0m0s\s+1\s+true$/) }
  end
end
