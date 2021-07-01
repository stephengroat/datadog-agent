# manually start the NPM driver
windows_service 'system-probe-driver' do
  service_name 'ddnpm'
  action :start
end
