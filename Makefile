deploy:
	ssh isucon11-qualify-1 " \
		cd /home/isucon; \
		git checkout .; \
		git fetch; \
		git checkout $(BRANCH); \
		git reset --hard origin/$(BRANCH)"

build:
	ssh isucon11-qualify-1 " \
		cd /home/isucon/webapp/go; \
		/home/isucon/local/go/bin/go build -o isucondition main.go; \
		sudo systemctl restart isucondition.go.service"

mariadb-deploy:
	ssh isucon11-qualify-2 "sudo dd of=/etc/mysql/mariadb.conf.d/50-server.cnf" < ./etc/mysql/mariadb.conf.d/50-server.cnf

mariadb-rotate:
	ssh isucon11-qualify-2 "sudo rm -f /var/log/mysql/mariadb-slow.log"

mariadb-restart:
	ssh isucon11-qualify-2 "sudo systemctl restart mariadb.service"

nginx-deploy:
	ssh isucon11-qualify-1 "sudo dd of=/etc/nginx/nginx.conf" < ./etc/nginx/nginx.conf
	ssh isucon11-qualify-1 "sudo dd of=/etc/nginx/sites-available/isucondition.conf" < ./etc/nginx/sites-available/isucondition.conf

nginx-rotate:
	ssh isucon11-qualify-1 "sudo rm -f /var/log/nginx/access.log"

nginx-reload:
	ssh isucon11-qualify-1 "sudo systemctl reload nginx.service"

nginx-restart:
	ssh isucon11-qualify-1 "sudo systemctl restart nginx.service"

.PHONY: bench
bench:
	ssh isucon11-qualify-1 " \
		cd /home/isucon/bench; \
		./bench -all-addresses 127.0.0.11 -target 127.0.0.11:443 -tls -jia-service-url http://127.0.0.1:4999"

pt-query-digest:
	ssh isucon11-qualify-1 "sudo pt-query-digest --limit 10 /var/log/mysql/mariadb-slow.log"

ALPSORT=sum
ALPM="/api/isu/.+/icon,/api/isu/.+/graph,/api/isu/.+/condition,/api/isu/[-a-z0-9]+,/api/condition/[-a-z0-9]+,/api/catalog/.+,/api/condition\?,/isu/........-....-.+,/?jwt=.+"
OUTFORMAT=count,method,uri,min,max,sum,avg,p99

alp:
	ssh isucon11-qualify-1 "sudo alp ltsv --file=/var/log/nginx/access.log --nosave-pos --pos /tmp/alp.pos --sort $(ALPSORT) --reverse -o $(OUTFORMAT) -m $(ALPM) -q"

.PHONY: pprof
pprof:
	ssh isucon11-qualify-1 "/home/isucon/local/go/bin/go tool pprof -http=0.0.0.0:1080 webapp/go/isucondition http://localhost:6060/debug/pprof/profile?seconds=75"

pprof-show:
	$(eval latest := $(shell ssh isucon11-qualify-1 "ls -rt ~/pprof/ | tail -n 1"))
	scp isucon11-qualify-1:~/pprof/$(latest) ./pprof
	go tool pprof -http=":1080" ./pprof/$(latest)

pprof-kill:
	ssh isucon11-qualify-1 "pgrep -f 'pprof' | xargs kill;"
