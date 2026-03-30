import os

def trim_string(text, max_length):
    text = text.strip()
    if len(text) <= max_length:
        return text
    # Cut off at max_length, then find the last space so we don't cut a word in half
    truncated = text[:max_length]
    last_space = truncated.rfind(' ')
    if last_space > -1:
        return truncated[:last_space]
    return truncated

def trim_keywords(text, max_length):
    text = text.strip()
    # Split by comma to keep keyword integrity
    keywords = [k.strip() for k in text.split(',')]
    result = []
    current_length = 0
    
    for kw in keywords:
        # We join with just A COMMA (no space) to save precious characters for keywords!
        # length of keyword + 1 character for the comma (if not the first word)
        addition = len(kw) + (1 if current_length > 0 else 0)
        
        if current_length + addition <= max_length:
            result.append(kw)
            current_length += addition
        else:
            break
            
    return ','.join(result) # NO spaces after commas for App Store

# iOS Constraints
ios_path = 'fastlane/metadata'
if os.path.exists(ios_path):
    for locale in os.listdir(ios_path):
        loc_path = os.path.join(ios_path, locale)
        if not os.path.isdir(loc_path) or locale == 'android':
            continue
            
        name_path = os.path.join(loc_path, 'name.txt')
        if os.path.exists(name_path):
            with open(name_path, 'r', encoding='utf-8') as f:
                content = f.read()
            with open(name_path, 'w', encoding='utf-8') as f:
                f.write(trim_string(content, 30))
                
        sub_path = os.path.join(loc_path, 'subtitle.txt')
        if os.path.exists(sub_path):
            with open(sub_path, 'r', encoding='utf-8') as f:
                content = f.read()
            with open(sub_path, 'w', encoding='utf-8') as f:
                f.write(trim_string(content, 30))
                
        kw_path = os.path.join(loc_path, 'keywords.txt')
        if os.path.exists(kw_path):
            with open(kw_path, 'r', encoding='utf-8') as f:
                content = f.read()
            with open(kw_path, 'w', encoding='utf-8') as f:
                f.write(trim_keywords(content, 100))

# Android Constraints
android_path = 'fastlane/metadata/android'
if os.path.exists(android_path):
    for locale in os.listdir(android_path):
        loc_path = os.path.join(android_path, locale)
        if not os.path.isdir(loc_path):
            continue
            
        title_path = os.path.join(loc_path, 'title.txt')
        if os.path.exists(title_path):
            with open(title_path, 'r', encoding='utf-8') as f:
                content = f.read()
            with open(title_path, 'w', encoding='utf-8') as f:
                f.write(trim_string(content, 50)) # Google Play title limit is 50
                
        short_desc = os.path.join(loc_path, 'short_description.txt')
        if os.path.exists(short_desc):
            with open(short_desc, 'r', encoding='utf-8') as f:
                content = f.read()
            with open(short_desc, 'w', encoding='utf-8') as f:
                f.write(trim_string(content, 80)) # Short desc is 80
