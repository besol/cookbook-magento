# General settings
default[:magento][:version] = "1.7.0.2"
default[:magento][:sample_data_version] = "1.6.1.0"
default[:magento][:url] = "http://www.magentocommerce.com/downloads/assets/#{default[:magento][:version]}/magento-#{default[:magento][:version]}.tar.gz"
default[:magento][:dir] = "/var/www/magento"
default[:magento][:sample_data_url] = "http://www.magentocommerce.com/downloads/assets/#{default[:magento][:sample_data_version]}/magento-sample-data-#{default[:magento][:sample_data_version]}.tar.gz"
default[:magento][:run_type] = "store"
default[:magento][:run_codes] = Array.new
default[:magento][:session]['save'] = 'db'




# Required packages
case node["platform_family"]
when "rhel", "fedora"
  default[:magento][:packages] = ['php-cli', 'php-common', 'php-curl', 'php-gd', 'php-mcrypt', 'php-mysql', 'php-pear', 'php-apc', 'php-xml']
else
  default[:magento][:packages] = ['php5-cli', 'php5-common', 'php5-curl', 'php5-gd', 'php5-mcrypt', 'php5-mysql', 'php-pear', 'php-apc']
end

# Web Server
default[:magento][:webserver] = 'nginx'
default[:magento][:user] = 'magento'

set['php-fpm']['pools'] = ["magento"]

set_unless['php-fpm']['pool']['magento']['listen'] = "127.0.0.1:9000"
set_unless['php-fpm']['pool']['magento']['allowed_clients'] = ["127.0.0.1"]
set_unless['php-fpm']['pool']['magento']['user'] = 'magento'
set_unless['php-fpm']['pool']['magento']['group'] = 'magento'
set_unless['php-fpm']['pool']['magento']['process_manager'] = "dynamic"
set_unless['php-fpm']['pool']['magento']['max_children'] = 50
set_unless['php-fpm']['pool']['magento']['start_servers'] = 5
set_unless['php-fpm']['pool']['magento']['min_spare_servers'] = 5
set_unless['php-fpm']['pool']['magento']['max_spare_servers'] = 35
set_unless['php-fpm']['pool']['magento']['max_requests'] = 500

# Credentials
::Chef::Node.send(:include, Opscode::OpenSSL::Password)

default[:magento][:db][:database] = "magento"
default[:magento][:db][:username] = "magentouser"
default[:magento][:db][:sample_data] = false
set_unless[:magento][:db][:password] = secure_password

#
# NewRelic Attributes
#
default['magento']['newrelic']['enabled'] = nil
default['magento']['newrelic']['logfile'] = nil
default['magento']['newrelic']['loglevel'] = nil
default['magento']['newrelic']['appname'] = nil
default['magento']['newrelic']['daemon']['logfile'] = "/var/log/newrelic/newrelic-daemon.log"
default['magento']['newrelic']['daemon']['loglevel'] = nil
default['magento']['newrelic']['daemon']['port'] = nil
default['magento']['newrelic']['daemon']['max_threads'] = nil
default['magento']['newrelic']['daemon']['ssl'] = nil
default['magento']['newrelic']['daemon']['ssl_ca_path'] = nil
default['magento']['newrelic']['daemon']['ssl_ca_bundle'] = nil
default['magento']['newrelic']['daemon']['proxy'] = nil
default['magento']['newrelic']['daemon']['pidfile'] = nil
default['magento']['newrelic']['daemon']['location'] = nil
default['magento']['newrelic']['daemon']['collector_host'] = nil
default['magento']['newrelic']['daemon']['dont_launch'] = nil
default['magento']['newrelic']['capture_params'] = nil
default['magento']['newrelic']['ignored_params'] = nil
default['magento']['newrelic']['error_collector']['enable'] = nil
default['magento']['newrelic']['error_collector']['record_database_errors'] = nil
default['magento']['newrelic']['error_collector']['prioritize_api_errors'] = nil
default['magento']['newrelic']['browser_monitoring']['auto_instrument'] = nil
default['magento']['newrelic']['transaction_tracer']['enable'] = nil
default['magento']['newrelic']['transaction_tracer']['threshold'] = nil
default['magento']['newrelic']['transaction_tracer']['detail'] = nil
default['magento']['newrelic']['transaction_tracer']['slow_sql'] = nil
default['magento']['newrelic']['transaction_tracer']['stack_trace_threshold'] = nil
default['magento']['newrelic']['transaction_tracer']['explain_threshold'] = nil
default['magento']['newrelic']['transaction_tracer']['record_sql'] = nil
default['magento']['newrelic']['transaction_tracer']['custom'] = nil
default['magento']['newrelic']['framework'] = nil
default['magento']['newrelic']['webtransaction']['name']['remove_trailing_path'] = nil
default['magento']['newrelic']['webtransaction']['name']['functions'] = nil
default['magento']['newrelic']['webtransaction']['name']['files'] = nil



