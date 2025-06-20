#!/usr/bin/env bash

# Install Ruby dependencies
echo "Installing Ruby dependencies..."
bundle install

# Start the Sinatra application
echo "Starting Sinatra application on port 8000..."
bundle exec puma -p 8000 -e development
