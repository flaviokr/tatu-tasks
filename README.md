# Setup
### Build the image:
```bash
make
```

### Run the container:
```bash
make run
```

### For configuring a new domain:
```ruby
post '/' do
  JSON.parse(request.body.read)['challenge']
end
```

### For bumping version
First, edit the Makefile's 'version' variable default value to the new version number.
Then, run:
```bash
make
version=0.0.1 make clean
```
Replacing 0.0.1 by the previous version
