dns_domain = "devmonkey.online."
env        = "prod"

databases = {
  postgresql = {
    instance_type = "t3.small"
    ports = {
      ssh        = 22
      postgresql = 5432
    }
  }
}

apps = {

  frontend = {
    instance_type = "t3.small"
    ports = {
      ssh      = 22
      frontend = 80
    }
  }

  auth-service = {
    instance_type = "t3.small"
    ports = {
      ssh          = 22
      auth-service = 8081
    }
  }

  portfolio-service = {
    instance_type = "t3.small"
    ports = {
      ssh               = 22
      portfolio-service = 8080
    }
  }

  analytics-service = {
    instance_type = "t3.small"
    ports = {
      ssh               = 22
      analytics-service = 8000
    }
  }

}
