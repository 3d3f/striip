# Matugen Custom Configuration

Place your custom matugen snippets (`.toml`) in this directory and your source templates in the `../templates.d` folder.

### How it works
* Every `.toml` file in this directory is merged with the base `config.toml` and saved to `~/.cache/quickshell/matugen/config.toml` before running matugen.
* You can write all your configuration in a single file or create a separate `.toml` file for every template to keep things organized.
* To debug or check the final result, you can inspect the merged configuration with:
  `cat ~/.cache/quickshell/matugen/config.toml`

### Benefits of modularity
Creating one file for every template config will improve fault tolerance: 
If one file has a syntax error, the merge script will skip it and load the rest, ensuring that most of your UI remains themed.

## Recommended Structure
- `kitty.toml`
- `waybar.toml`
- `rofi.toml`
- `hyprland.toml`

## Example Snippet (`conf.d/example.toml`)
```toml
[templates.my_app]
input_path = '~/.config/matugen/templates.d/my_app.mustache'
output_path = '~/.cache/my_app/colors.css'
