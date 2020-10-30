import os
import argparse
from shutil import copyfile


def combine(outFname = 'test.mp4',quality=20,frameRate = '24',aspectRatio='2560x1049', inpath='', fullQuality=False, duration=None):
	'''
	Combine set of png files into a mp4 video.
	Images need to be in the same directory as the script.

	Parameters
	----------
	outFname : str ('test.mp4')
		Filename for outfile
	quality : int (1)
		Quality (lower is higher)
	frameRate : int (60)
		Frame rate of video.
	aspectRatio : str ('2560x1049')
		Aspect ratio of images.
	fullQuality: boolean (default=False)
	 	If True, it will run ffmpeg with -c:v copy and generate a high quality mkv.
	duration: int (optional)
		Duration of video in seconds. If provided, the frameRate is adjusted to fit within the given time. 
	'''
	inpath = '.' if inpath =='' else inpath
	fnames = [f for f in os.listdir(inpath) if 'png'==f.split('.')[-1]]
	cycles = [int(f.split('cycle_')[-1].split('_')[0].replace('.png','')) for f in fnames]
	order = sorted(range(len(cycles)), key=lambda k: cycles[k])

	digits = 5
	j = 0
	created_files = []
	for i in order:
		src = fnames[i]
		dst = 'cycle_'+('0'*digits+str(j))[-digits:]+'.png'
		if inpath !='.':
			src = os.path.join(inpath,src)
			dst = os.path.join(inpath,dst)
		print(src,dst)
		# os.rename(src, dst)
		copyfile(src, dst)
		created_files.append(dst)
		j+=1

	if duration is not None:
		frameRate = round(len(created_files)/duration,3)

	if inpath!='.':
		inpath = os.path.join(inpath,f'cycle_%0{digits}d.png')
	else:
		inpath = f'cycle_%0{digits}d.png'

	if fullQuality:
		outFname = outFname.split('.')[0]+'.mkv'
		cmd = f'ffmpeg -framerate {frameRate} -s {aspectRatio} -i {inpath} -c:v copy {outFname}'
	else:
		cmd = f'ffmpeg -r {frameRate} -s {aspectRatio} -f image2 -i {inpath} -vcodec libx264 -crf {quality} -pix_fmt yuv420p -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2" {outFname}'

	print('Result will be written in:',outFname)
	print(cmd)
	try:
		os.system(cmd)
	except Exception as exc:
		print(traceback.format_exc())
		print(exc)	
	for dst in created_files:
		os.remove(dst)


if __name__ == "__main__":
	parser = argparse.ArgumentParser()
	parser.add_argument('-outfname', type=str, help='Filname for outfile')
	parser.add_argument('-framerate', type=int, help='Video frame rate')
	parser.add_argument('-inpath', type=str, help='Video frame rate')
	parser.add_argument('-fullquality', type=bool, help='TRUE for full quality')
	parser.add_argument('-duration', type=int, help='Duration of video, overrides framerate')
	
	args = parser.parse_args()
	
	combine(
		outFname = 'output.mp4' if args.outfname is None else args.outfname,
		quality = 20,
		frameRate = '24' if args.framerate is None else args.framerate,
		aspectRatio='2560x1049',
		inpath = '' if args.inpath is None else args.inpath,
		fullQuality = False if args.fullquality is None else args.fullquality,
		duration = args.duration
	)
