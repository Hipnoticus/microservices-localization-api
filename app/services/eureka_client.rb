# frozen_string_literal: true

require 'httparty'
require 'socket'

# Registers this service with Netflix Eureka for Spring Cloud service discovery.
# Sends heartbeats every 30 seconds to maintain registration.
class EurekaClient
  EUREKA_URL = ENV.fetch('EUREKA_URL', 'http://discUser:discPassword@hipnoticus-discovery-api:8082/eureka')
  APP_NAME = 'LOCALIZATION-SERVICE'
  PORT = 4001

  def self.hostname
    # Use container name from env or Docker hostname
    @hostname ||= ENV.fetch('HOSTNAME_OVERRIDE', 'hipnoticus-localization-api')
  end

  def self.ip_address
    @ip_address ||= begin
      Socket.ip_address_list.detect(&:ipv4_private?)&.ip_address || '127.0.0.1'
    end
  end

  def self.instance_id
    "#{hostname}:#{APP_NAME.downcase}:#{PORT}"
  end

  def self.register
    body = <<~XML
      <instance>
        <instanceId>#{instance_id}</instanceId>
        <hostName>#{hostname}</hostName>
        <app>#{APP_NAME}</app>
        <ipAddr>#{ip_address}</ipAddr>
        <status>UP</status>
        <overriddenstatus>UNKNOWN</overriddenstatus>
        <port enabled="true">#{PORT}</port>
        <securePort enabled="false">443</securePort>
        <countryId>1</countryId>
        <dataCenterInfo class="com.netflix.appinfo.InstanceInfo$DefaultDataCenterInfo">
          <name>MyOwn</name>
        </dataCenterInfo>
        <leaseInfo>
          <renewalIntervalInSecs>30</renewalIntervalInSecs>
          <durationInSecs>90</durationInSecs>
        </leaseInfo>
        <homePageUrl>http://#{hostname}:#{PORT}/</homePageUrl>
        <statusPageUrl>http://#{hostname}:#{PORT}/health</statusPageUrl>
        <healthCheckUrl>http://#{hostname}:#{PORT}/health</healthCheckUrl>
        <vipAddress>#{APP_NAME.downcase}</vipAddress>
        <secureVipAddress>#{APP_NAME.downcase}</secureVipAddress>
      </instance>
    XML

    url = "#{EUREKA_URL}/apps/#{APP_NAME}"
    response = HTTParty.post(url, body: body, headers: { 'Content-Type' => 'application/xml' }, timeout: 10)

    if response.code == 204
      puts "[Eureka] Registered #{APP_NAME} (#{instance_id})"
    else
      puts "[Eureka] Registration failed: #{response.code} #{response.body}"
    end
  rescue StandardError => e
    puts "[Eureka] Registration error: #{e.message}"
  end

  def self.heartbeat
    url = "#{EUREKA_URL}/apps/#{APP_NAME}/#{instance_id}"
    response = HTTParty.put(url, timeout: 5)

    if response.code == 200
      # Heartbeat OK
    elsif response.code == 404
      # Instance not found — re-register
      puts '[Eureka] Instance not found, re-registering...'
      register
    else
      puts "[Eureka] Heartbeat failed: #{response.code}"
    end
  rescue StandardError => e
    puts "[Eureka] Heartbeat error: #{e.message}"
  end

  def self.deregister
    url = "#{EUREKA_URL}/apps/#{APP_NAME}/#{instance_id}"
    HTTParty.delete(url, timeout: 5)
    puts "[Eureka] Deregistered #{APP_NAME}"
  rescue StandardError => e
    puts "[Eureka] Deregister error: #{e.message}"
  end
end
