# installation clone recursively

```
$ git clone --recurse-submodules  git@github.com:fxfactorial/celestia-iphone.git
```

Commit of gosigar should be `fab926c0fd9f73434fc6f4fd1c3f647c1d202a8f`

Commit of celestia-node should be `0f7680d5e625629a4d203e825084a8653ee5166b`

# Fix build issue

Then go to `celestia-node` and make `make ios` work, aka fix the 99designs/keyring issue
