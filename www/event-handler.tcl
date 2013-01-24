evnt::handle_events \
  -timeout 10 \
  -spec {
      {"something-happened" {
	      ns_write "Hey! Looks like something has happened!\n"
	  }
      }
      {"something-else-happened" {
	      ns_write "Wow! Now happened something else!\n"
	  }
      }
  }