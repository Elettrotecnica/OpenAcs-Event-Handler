evnt::handle_events \
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