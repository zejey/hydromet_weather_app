import requests

url = "https://api.weatherlink.com/v2/current/205011"
params = {"api-key": "ysfvgjxvypxd5uq4kmojgqqoixmh3cdy"}
headers = {"x-api-secret": "allkoponohswxku4dtumss2ykudmul4r"}

response = requests.get(url, params=params, headers=headers)
print(response.json())
