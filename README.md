# hey-cira
repo for various CIRA project deliverables

## Using the screen scraper

1. Install rbenv

  ```
  brew install rbenv
  ```

2. Grab the latest stable release:

  ```
  rbenv install 2.4.2
  ```

  Use the above release to ensure compatibility. If, for some reason, you need to upgrade ruby, run `rbenv install -l` to see what versions are available. Update this document and `.ruby-version` in the project root to reflect the new version.

3. Append the following to your .bashrc or .zshrc:

  ```
  eval "$(rbenv init -)"
  ```

4. Resource your shell init script or open a new terminal.

5. Change to the root project directory and check that it's using rbenv's ruby:

  ```
  cd hey-cira
  ruby -v
  ```

6. Install required gems:

  ```
  gem install nokogiri
  gem install httparty
  gem install pry
  gem install mechanize
  ```