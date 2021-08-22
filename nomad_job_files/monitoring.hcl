job "faas-monitoring" {
  datacenters = ["dc1"]

  type = "service"

  constraint {
    attribute = "${attr.cpu.arch}"
    operator  = "!="
    value     = "arm"
  }

  group "faas-monitoring" {
    count = 1

    restart {
      attempts = 10
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }

		volume "grafana" {
			type = "host"
			read_only = false
			source = "grafana"
		}

    task "alertmanager" {
      driver = "docker"

			artifact {
			  source      = "https://raw.githubusercontent.com/Crystalix007/faas-nomad/master/nomad_job_files/templates/alertmanager.yml"
			  destination = "local/alertmanager.yml.tpl"
				mode        = "file"
			}

      template {
        source        = "local/alertmanager.yml.tpl"
        destination   = "/etc/alertmanager/alertmanager.yml"
        change_mode   = "noop"
        change_signal = "SIGINT"
      }

      config {
        image = "prom/alertmanager:v0.22.2"

        port_map {
          http = 9093
        }

        dns_servers = ["${NOMAD_IP_http}", "8.8.8.8", "8.8.8.4"]

        args = [
          "--config.file=/etc/alertmanager/alertmanager.yml",
          "--storage.path=/alertmanager",
        ]

        volumes = [
          "etc/alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml",
        ]
      }

      resources {
        cpu    = 100 # 100 MHz
        memory = 128 # 128MB

        network {
          mbits = 10

          port "http" {}
        }
      }

      service {
        port = "http"
        name = "alertmanager"
        tags = ["faas"]
      }
    }

    task "prometheus" {
      driver = "docker"

			artifact {
			  source      = "https://raw.githubusercontent.com/Crystalix007/faas-nomad/master/nomad_job_files/templates/prometheus.yml"
			  destination = "local/prometheus.yml.tpl"
				mode        = "file"
			}

			artifact {
			  source      = "https://raw.githubusercontent.com/Crystalix007/faas-nomad/master/nomad_job_files/templates/alert.rules.yml"
			  destination = "local/alert.rules.yml.tpl"
				mode        = "file"
			}

      template {
        source        = "local/prometheus.yml.tpl"
        destination   = "/etc/prometheus/prometheus.yml"
        change_mode   = "noop"
        change_signal = "SIGINT"
      }

      template {
        source        = "local/alert.rules.yml.tpl"
        destination   = "/etc/prometheus/alert.rules.yml"
        change_mode   = "noop"
        change_signal = "SIGINT"
      }

      config {
        image = "prom/prometheus:v2.29.1"

        args = [
          "--config.file=/etc/prometheus/prometheus.yml",
          "--storage.tsdb.path=/prometheus",
        ]

        dns_servers = ["${NOMAD_IP_http}", "8.8.8.8", "8.8.8.4"]

        port_map {
          http = 9090
        }

        volumes = [
          "etc/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml",
          "etc/prometheus/alert.rules.yml:/etc/prometheus/alert.rules.yml",
        ]
      }

      resources {
        cpu    = 200 # 200 MHz
        memory = 256 # 256MB

        network {
          mbits = 10

          port "http" {
            static = 9090
          }
        }
      }

      service {
        port = "http"
        name = "prometheus"
        tags = ["faas"]

        check {
          type     = "http"
          port     = "http"
          interval = "10s"
          timeout  = "2s"
          path     = "/graph"
        }
      }
    }

    task "grafana" {
      driver = "docker"

      config {
        image = "grafana/grafana:8.1.2"

        port_map {
          http = 3000
        }
      }

      resources {
        cpu    = 200 # 500 MHz
        memory = 256 # 256MB

        network {
          mbits = 10

          port "http" {
            static = 3001
          }
        }
      }

      service {
        port = "http"
        name = "grafana"
        tags = ["faas"]
      }
    }
  }
}
