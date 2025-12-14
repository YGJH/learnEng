from google import genai

client = genai.Client(api_key='AIzaSyCzqk4seKykYFrx04OYUx0lDMNDYtvEu0U')

print("List of models that support generateContent:\n")
for m in client.models.list():
    for action in m.supported_actions:
        if action == "generateContent":
            print(m.name)

print("List of models that support embedContent:\n")
for m in client.models.list():
    for action in m.supported_actions:
        if action == "embedContent":
            print(m.name)
