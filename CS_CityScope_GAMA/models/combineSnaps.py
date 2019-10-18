import os
def combine(outFname = 'test.mp4',quality=1,frameRate = '10',aspectRatio='2560x1049'):
	'''
	Combine set of png files into a mp4 video.

	Parameters
	----------
	outFname : str ('test.mp4')
		Filename for outfile
	quality : int (20)
		Quality (lower is higher)
	frameRate : int (60)
		Frame rate of video.
	aspectRatio : str ('2560x1049')
		Aspect ratio of images.
	'''
	fnames = [f for f in os.listdir('.') if 'png'==f.split('.')[-1]]
	cycles = [int(f.split('cycle_')[-1].split('_')[0].replace('.png','')) for f in fnames]
	order = sorted(range(len(cycles)), key=lambda k: cycles[k])

	digits = 5
	j = 0
	for i in order:
		src = fnames[i]
		dst = 'cycle_'+('0'*digits+str(j))[-digits:]+'.png'
		print(src,dst)
		os.rename(src, dst)
		j+=1

	cmd = 'ffmpeg -r '+str(frameRate)+' -f image2 -s '+aspectRatio+' -i cycle_%0'+str(digits)+'d.png -vf scale=1280:-2 -vcodec libx264 -crf '+str(quality)+'  -pix_fmt yuv420p '+outFname
	print(cmd)
	os.system(cmd)

if __name__ == "__main__":
	combine()