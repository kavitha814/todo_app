import os
import re

def convert_to_light_theme(directory):
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith(".dart"):
                path = os.path.join(root, file)
                with open(path, "r", encoding="utf-8") as f:
                    content = f.read()

                # Basic Theme Replacements
                content = content.replace("Brightness.dark", "Brightness.light")
                content = content.replace("0xFF121212", "0xFFFFFFFF") # Main background
                content = content.replace("0xFF363636", "0xFFF5F5F5") # Cards/BottomSheets
                content = content.replace("0xFF1D1D1D", "0xFFF5F5F5") # Primary surfaces
                content = content.replace("Colors.grey[800]", "Colors.grey[300]")
                content = content.replace("Colors.grey[900]", "Colors.grey[200]")

                # Careful Text & Icon replacements
                # First, temporarily mask the white text inside primary buttons if we want
                content = re.sub(r"(backgroundColor:\s*(?:const\s*)?Color\(0xFF8875FF\).*?color:\s*)Colors\.white", r"\1M4SK_WH1T3", content, flags=re.DOTALL)
                
                # Replace remaining basic colors
                content = content.replace("Colors.white54", "Colors.black54")
                content = content.replace("Colors.white70", "Colors.black87")
                content = content.replace("Colors.white24", "Colors.black26")
                content = content.replace("Colors.white10", "Colors.black12")
                content = content.replace("Colors.white", "Colors.black87")
                
                # Unmask
                content = content.replace("M4SK_WH1T3", "Colors.white")

                with open(path, "w", encoding="utf-8") as f:
                    f.write(content)

convert_to_light_theme("lib")
print("Done")

