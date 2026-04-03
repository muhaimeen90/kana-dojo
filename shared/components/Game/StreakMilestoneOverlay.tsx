'use client';

import { useEffect } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import confetti from 'canvas-confetti';
import { Flame } from 'lucide-react';
import { useHasFinePointer } from '@/shared/hooks/generic/useHasFinePointer';
import { type StreakMilestone } from '@/shared/lib/game/streakMilestones';

interface StreakMilestoneOverlayProps {
  milestone: StreakMilestone | null;
  onDismiss: () => void;
}

const layerVariants = {
  hidden: { opacity: 0, x: 120 },
  visible: {
    opacity: 1,
    x: 0,
    transition: {
      x: { type: 'spring' as const, stiffness: 320, damping: 30, mass: 0.85 },
      opacity: { duration: 0.24 },
    },
  },
  exit: {
    opacity: 0,
    x: -140,
    transition: {
      x: { type: 'spring' as const, stiffness: 320, damping: 30, mass: 0.85 },
      opacity: { duration: 0.2 },
    },
  },
};

const contentVariants = {
  hidden: {},
  visible: {
    transition: {
      staggerChildren: 0.1,
      delayChildren: 0.12,
    },
  },
};

const itemVariants = {
  hidden: { opacity: 0, y: 18, scale: 0.96 },
  visible: {
    opacity: 1,
    y: 0,
    scale: 1,
    transition: { type: 'spring' as const, stiffness: 280, damping: 24, mass: 0.9 },
  },
};

export default function StreakMilestoneOverlay({
  milestone,
  onDismiss,
}: StreakMilestoneOverlayProps) {
  const hasFinePointer = useHasFinePointer();

  useEffect(() => {
    if (!milestone) return;

    confetti({
      particleCount: 100,
      spread: 70,
      origin: { y: 0.6 },
    });
    setTimeout(() => {
      confetti({
        particleCount: 50,
        angle: 60,
        spread: 55,
        origin: { x: 0 },
      });
      confetti({
        particleCount: 50,
        angle: 120,
        spread: 55,
        origin: { x: 1 },
      });
    }, 180);
  }, [milestone]);

  return (
    <AnimatePresence>
      {milestone && (
        <motion.div
          key={`streak-${milestone}`}
          variants={layerVariants}
          initial='hidden'
          animate='visible'
          exit='exit'
          className='fixed inset-0 z-[70] flex h-full w-full items-center justify-center bg-(--background-color)'
          onClick={onDismiss}
          role='dialog'
          aria-modal='true'
          aria-label={`${milestone} in a row`}
        >
          <motion.div
            variants={contentVariants}
            initial='hidden'
            animate='visible'
            className='mx-auto flex w-full max-w-4xl flex-col items-center gap-6 px-6 text-center select-none'
          >
            <motion.div
              variants={itemVariants}
              className='rounded-3xl border-2 border-(--main-color)/20 bg-(--card-color) p-6'
            >
              <Flame className='h-20 w-20 text-(--main-color)' strokeWidth={2.5} />
            </motion.div>

            <motion.h2
              variants={itemVariants}
              className='text-4xl font-black tracking-tighter text-(--main-color) sm:text-5xl'
            >
              {milestone} in a row!
            </motion.h2>

            {/* <motion.p
              variants={itemVariants}
              className='max-w-2xl text-xl font-semibold text-(--secondary-color) sm:text-2xl'
            >
              + {message}
            </motion.p> */}

            <motion.p
              variants={itemVariants}
              className='pt-2 text-sm text-(--secondary-color) opacity-50 sm:text-base'
            >
              {hasFinePointer ? 'click' : 'tap'} to continue
            </motion.p>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}

