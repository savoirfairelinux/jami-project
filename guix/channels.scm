(list (channel
       (inherit %default-guix-channel)
       ;; Use the staging branch for now, as it includes more debug
       ;; symbols and fixes a propagation conflict between
       ;; gdk-pixbuf+svg and gdk-pixbuf.
       (branch "staging")
       (commit
        "42231bc15df441d6426dec57283aca9ae7a03fcf")))
