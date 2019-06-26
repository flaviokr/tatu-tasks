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
