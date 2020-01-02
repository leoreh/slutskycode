
basepath = 'E:\Data\Others\DZ\Field\Acute recordings\Long recordings\APPPS1';
cd(basepath)
filename = dir('*.abf');
files = {filename.name};
nfiles = 1 : length(files);     % address specific files

forceLoad = true;
analyze = true;
saveFig = true;
tetrodes = false;

for i = 1
    
    if forceLoad
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % data
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        % tetrodes
        if tetrodes
            ch = 5;
            [~, basename] = fileparts(basepath);
            load([basename '.lfp.mat'])
            fs = lfp.fs;
            sig = double(lfp.data(:, ch));
            tstamps = lfp.timestamps;
            
            % field
        else
            [~, basename] = fileparts(files{i});
            if exist([basename '_lfp.mat'])
                load([basename '_lfp.mat'])
                load([basename '_info.mat'])
            else
                filename = [basename '.abf'];
                [lfp.data, info] = abf2load(filename);
                
                save([basename '_lfp.mat'], 'lfp')
                save([basename '_info.mat'], 'info')
            end
            fs_orig = info.fADCSequenceInterval;
            fs_orig = 1 / (fs_orig / 1000000);
            fs = 1250;
        end
    end
    
    
    if analyze        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % prepare signal
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % resmaple
        if ~tetrodes
            sig = resample(double(lfp.data), fs, round(fs_orig));
            sig(end : -1 : end - 60 * fs) = [];
            tstamps = [1 : length(sig)] / fs;
        end
        
        % filter
        linet = lineDetect('x', sig, 'fs', fs, 'graphics', false);
        sig = lineRemove(sig, linet, [], [], 0, 1);
        
%         x = filterLFP(sig, 'fs', fs, 'stopband', [45 55], 'order', 6,...
%             'type', 'butter', 'dataOnly', true, 'graphics', false,...
%             'saveVar', false);
        
       %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % iis
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        % prep signal
        r = rms(sig);
        x = (sig / r) .^ 2;
        x = zscore(x);    
        
        % investigate threshold
%         j = 1;
%         idx = 5 : 0.5 : floor(max(x));
%         nevents = zeros(1, length(idx));
%         for i = 1 : length(idx)
%             nevents(i) = sum(x > idx(i));
%         end
%         figure
%         plot(idx, cumsum(nevents))
%         yyaxis right
%         plot(idx, cumsum(log10(nevents)))
%         axis tight
        
%         histogram((nevents), 50, 'Normalization', 'cdf')
        
        % detect
        thr = 15;
        iie = find(diff(x > thr) > 0);    

        % select local maximum
        marg = round(0.1 * fs);
        peak = zeros(length(iie), 1);
        pos = zeros(length(iie), 1);
        seg = zeros(length(iie), marg * 2 + 1);
        for i = 1 : length(iie)
            seg(i, :) = sig(iie(i) - marg : iie(i) + marg);
            [peak(i), pos(i)] = max(abs(seg(i, :)));
            pos(i) = iie(i) - marg + pos(i);
            seg(i, :) = sig(pos(i) - marg : pos(i) + marg);
        end
        
        fseg = linspace(1, 250, 250);
        pwelch(seg(1, :), [], [], fseg, 1250);
        
        cwt(seg(1, :), 1250)
        
        % rate
        [iis.rate, iis.edges, iis.cents] = calcFR(pos, 'winCalc', [1, length(sig)],...
            'binsize', 60, 'smet', 'none', 'c2r', false);
        
        figure
        set(gcf, 'units','normalized','outerposition',[0 0 1 1]);
        
        % raw and iis
        subplot(3, 3, 1 : 2)
        plot(tstamps / 60, sig)
        yyaxis right
        plot(tstamps / 60, x, 'k')
        hold on
        plot(xlim, [thr thr], '--y')
        plot([pos pos] / fs / 60, [-10 -1], '--g', 'LineWidth', 2)
        xlim([120 130])
        
        % iis rate
        subplot(3, 3, 4 : 5)
        plot(iis.cents / fs / 60, iis.rate, 'k', 'LineWidth', 1)
        
        % iis waveforms
        subplot(3, 3, 3)
        xstamps = [1 : size(seg, 2)] / fs;
        plot(xstamps, seg')
        hold on
        axis tight
        stdshade(seg, 0.5, 'k', xstamps)
        


        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % delta power
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        % broad-band spectrogram
        freq = logspace(0, 2, 100);
        winsize = 1;       % win length [s]
        win = hann(2 ^ nextpow2(winsize * fs));
        
        [s, f, t, p] = spectrogram(sig, win, round(length(win) / 10), freq, fs,...
            'yaxis', 'psd');
        
        % z-score. great way of comparing changes within a signal
        z = zscore(10 * log10(abs(p)));
        
        % integrate power over delta and sigma band
        deltaf = [1 4];
        [~, deltaidx] = min(abs(f - deltaf));
        zdelta = sum(z(deltaidx(1) : deltaidx(2), :), 1);
        sigmaf = [9 25];
        [~, sigmaidx] = min(abs(f - sigmaf));
        zsigma = sum(z(sigmaidx(1) : sigmaidx(2), :), 1);
        
        smf = round(15 / mode(diff(t)));
        zdelta = bz_NormToRange(zdelta, [0 1]);
        zdelta = smooth(zdelta, smf);
        zsigma = bz_NormToRange(zsigma, [0 1]);
        zsigma = smooth(zsigma, smf);
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % burst suppression
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        vars = {'std', 'sum', 'max'};
        bs = getBS('sig', sig, 'fs', fs, 'basepath', basepath,...
            'graphics', true, 'saveVar', false, 'binsize', 2,...
            'clustmet', 'gmm', 'vars', vars, 'basename', basename,...
            'saveFig', false, 'forceAnalyze', true);

    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % graphics
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    ff = gcf;
    
    % spectrogram
    s1 = subplot(3, 4, [9 : 10]);
    surf(t / 60, f, 10*log10(abs(p)), 'EdgeColor', 'none');
    axis xy;
    axis tight;
    view(0,90);
    origSize = get(gca, 'Position');
    colormap(jet);
    colorbar;
    ylabel('Frequency [Hz]');
    set(gca, 'YScale', 'log')
    set(s1, 'Position', origSize);
    set(gca, 'TickLength', [0 0])
    box off
    title('Wideband spectrogram')
    
    % delta power
    splot = subplot(3, 4, [5 : 6]);
    subplot(splot)
    hold on
    plot(t / 60, zdelta, 'r')
    plot(t / 60, zsigma, 'b')
    legend({'BSR', '[1-4 Hz]', '[9-25 Hz]'})
    xlabel('Time [min]');
    ylabel('[a.u.]')
    axis tight
    set(gca, 'TickLength', [0 0])
    box off
    title('Delta power and BSR')
    ylim([0 1])

    
    if saveFig
        figname = [basename '_anesthesia'];
        export_fig(figname, '-tif', '-transparent')
        % savePdf(figname, basepath, ff)
    end
  
    
    
end