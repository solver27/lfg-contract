import os
import json

if not os.path.exists("./artifacts"):
    os.mkdir("./artifacts")

if not os.path.exists("./artifacts/metadata"):
    os.mkdir("./artifacts/metadata")

for i in range(100):
    meta = dict()
    tokenId = str(i + 1)
    imageId = str(i + 9900)
    meta["name"] = "FireNFT#" + imageId
    meta["description"] = "Limited edition Fire NFT Avatars, to serve as your Gamerse profile picture. This Revolutionising NFT collection has a built-in burn function of 5% $LFG each time its sold on the secondary market. This unique feature creates scarcity and adds deflationary pressure increasing the value of the NFT overtime. Let the Gamerse begin!"
    meta["image"] = "https://gamerse.mypinata.cloud/ipfs/QmVRGsgbosiwu2StACHDfhHH2obfLEpz5uADRjpcWQK27W/black_" + \
        imageId + ".png"
    f = open("./artifacts/metadata/" + tokenId, "w")
    f.write(json.dumps(meta))
    f.close()
