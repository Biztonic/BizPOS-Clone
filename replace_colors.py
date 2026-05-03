import re

files_to_edit = [
    r'd:\BizPOS_Clone\lib\screens\auth\store_select_screen.dart',
    r'd:\BizPOS_Clone\lib\screens\auth\employee_login_screen.dart',
    r'd:\BizPOS_Clone\lib\screens\auth\station_lock_screen.dart',
    r'd:\BizPOS_Clone\lib\screens\auth\set_password_screen.dart'
]

color_map = {
    # .shade and withOpacity patterns
    r'Colors\.grey\.shade[0-9]+': 'AppColors.textSecondaryLight',
    r'Colors\.indigo\.shade[0-9]+': 'AppColors.primaryLight',
    r'Colors\.red\.shade[0-9]+': 'AppColors.error',
    
    # Generic generic
    r'Colors\.redAccent': 'AppColors.error',
    r'Colors\.red': 'AppColors.error',
    r'Colors\.green': 'AppColors.success',
    r'Colors\.teal': 'AppColors.success',
    r'Colors\.blue': 'AppColors.primary',
    r'Colors\.indigo': 'AppColors.primary',
    r'Colors\.amber': 'AppColors.warning',
    r'Colors\.orange': 'AppColors.warning',
    r'Colors\.orangeAccent': 'AppColors.warning',
    r'Colors\.grey': 'AppColors.textSecondaryLight',
}

for file_path in files_to_edit:
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # Add imports if not present
        if 'AppColors' not in content and 'import \'package:flutter/material.dart\';' in content:
            content = content.replace('import \'package:flutter/material.dart\';', 'import \'package:flutter/material.dart\';\nimport \'../../core/design/tokens/app_colors.dart\';\nimport \'../../core/design/tokens/app_typography.dart\';')
            
        for old, new in color_map.items():
            content = re.sub(old + r'(?![A-Za-z0-9_])', new, content)
            
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Processed {file_path}")
    except Exception as e:
        print(f"Failed {file_path}: {e}")

print('Replacement complete.')
