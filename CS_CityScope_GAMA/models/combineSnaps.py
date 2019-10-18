import os 
outFname = 'test.mp4'
fnames = [f for f in os.listdir('.') if 'png'==f.split('.')[-1]]
cycles = [int(f.split('cycle_')[-1].split('_')[0].replace('.png','')) for f in fnames]
order = sorted(range(len(cycles)), key=lambda k: cycles[k])

digits = 3
j = 0
for i in order:
	src = fnames[i]
	dst = 'cycle_'+('0'*digits+str(j))[-3:]+'.png'
	print(src,dst)
	os.rename(src, dst)
	j+=1

cmd = 'ffmpeg -r 60 -f image2 -s 2560x1049 -i cycle_%03d.png -vf scale=1280:-2 -vcodec libx264 -crf 25  -pix_fmt yuv420p '+outFname
print(cmd)
os.system(cmd)