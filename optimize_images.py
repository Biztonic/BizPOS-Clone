import os
files = [
    r'd:\BizPOS_Clone\lib\screens\auth\employee_login_screen.dart',
    r'd:\BizPOS_Clone\lib\screens\auth_screen.dart',
]
for f in files:
    with open(f, 'r', encoding='utf-8') as file:
        content = file.read()
    content = content.replace(
        "Image.asset('assets/logo.jpg', fit: BoxFit.cover,",
        "Image.asset('assets/logo.jpg', fit: BoxFit.cover, cacheWidth: 400,"
    )
    content = content.replace(
        "Image.asset('assets/logo.jpg', fit: BoxFit.cover)",
        "Image.asset('assets/logo.jpg', fit: BoxFit.cover, cacheWidth: 400)"
    )
    with open(f, 'w', encoding='utf-8') as file:
        file.write(content)
print('Done auth screens.')
