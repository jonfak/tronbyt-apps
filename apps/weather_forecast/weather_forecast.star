"""
Weather Forecast
Shows today's weather full-screen, then slides into a 3-up view with
today plus the next two days side by side (icon, high, low), using the
free Open-Meteo API (no key required).

Setup:
  Set the location config value for this app. No API key needed.
"""

load("encoding/base64.star", "base64")
load("encoding/json.star", "json")
load("http.star", "http")
load("math.star", "math")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

# --- Embedded icon PNGs (base64) ---
ICON_BIG_SUN = "iVBORw0KGgoAAAANSUhEUgAAABYAAAAUCAYAAACJfM0wAAADbElEQVR4nHWUT2hcVRjFf999byZJY8gfNVoiiIXMpDEp6EZiSDIhi9KFtUQiZNOFQlfiwl1XacGNIK6EgqCrUiFiQV2E0kiSmWaSduGiBFvjQhSlNSmJKdYkM+/d4+Il48xkvKvHud8599zvfu9AgyVhle+FsRBAt/pmtJx9vxqrr61ernpTxcywCoOdZkhK9irL/CaebJ0BZ4ZUGOxUMTNcrXVINgkjVguUrujmiXYzvISR65ZmCcBtg/2uWQJy3ZIwM7xunmiH0hVitRyI1t5AMwfuC9mcCtlrmu/t0SzBEecHTjVLoPneHhWy11TI5qo1jvb2sJ/5zIQKvecr+OrgiO70X9Sd/otaPTlSwQu955XPTNT3nSO2/+ubB9DKwHNY9BlBfJaUgRlEAUT+W3x4wYbW/qznVIQ1g+NSnfriWHKl8OH3PJMaZf+FiKYO+Ps32NuEZ5tDNkt5oucnAMgt1YhyqYHjivOVlydpKX+N9Zbo6k/jY8DDwyLsb5XoaErzJH7Lhu5fb8QPlc+coiXVRcl7jjnHnm3Z0NpdYp1DiHRr4t6XIGyBoAmQQyYinQOua2XgFM3q4h/vSTvHbnkrxIKzOL2KV4QpxMe3gbugVgjg8TqEzZBqg52fk1a4FEhgtCaHRmcw9xpeEU4hFvwQ2si9Dxv2wnyRVDjJ4ydi43YiFu+DBeAlQgyjCGDD9z+qp7tkJqeCZGanAulgdndLV9mJH/FUKoWnTFz2WODxKnMsSLETP2K3dFXCJZwDjdmpQMIdHbdkqASg5exp0u5Lml0n+0oKmgz2/DYlP23DP92o51QuXCOa/KZSsb8LacCG7+V1I/MSncF7xBoFILA82/Gndnr9Fy2fHMVszV7/ceuQe0S4IrrwYjOpls8x/wV/rC/a28SNnkCzBPRkcsi9Q3n3XRv/da9avFrY8d3xZjraP8H8NzayPpfkxJSxuGGkH7yC8TT7x+fJdQu+khlehcwZ5N7kr50PeOPB3uEf6A5PN8PT2TaN06qNrM9pYSw0w7O4YTa+FOEZJrZJG1+KWNxIkm1hLLSR9TmcVulsmzbDJ0lYf73DEKpKqQpW6LugW30fV2PVtfUhVBNzNr4UaQZnl2sDJan0IUa6HrbLeM3gbHwpqsbDRoU1QK47eWnZDvKbNdj/cYB/AUrKs2yVXuPzAAAAAElFTkSuQmCC"
ICON_BIG_PARTLY_CLOUDY = "iVBORw0KGgoAAAANSUhEUgAAABYAAAAUCAYAAACJfM0wAAAEBElEQVR4nK2US2zUVRTGf+f+H/NoYabTV6DhKekgBZ8kRimxGNwYEze0W10gJix8xgXxUaoJ6sYIO6OyMG5sURPZGA0aWyLRUCOW6YOHBKQU2047Q9uZ6cz873HRFhQHiYnf7uTc+7tfzr3fFW4hVYwIVnuTzyLSKNuHX9FuHOofFtnxfVl7k7sInK+gvkBbg4r0BNqXfAkjNRQb99+Kex0OoH3JV7Wv+XkFWegIqu3+jRq0t/kF7UvuVxDtxEhl5F/gIAKqPyS3yEMjA3q8eTdueS/WrMXxxrF8QmHobSR5p7SNDCztqwhW7XagXRa4SCq132ze3FXU3uYD1If2IatgvgiF3yHmwUT5M9k+vEu72x3qx6UiuLu72+no6Aj+cdhPD96LTv9M7J4y0dUC1jA9qGRHyiQiPtlSu2wbObK03r3JqnSIBFfOffHY/PKdba7R1b7LaMYs+5D+WCs1MbB5YN7BRMAJCWCwWJTHgSN6fOPTeOK4N5hqRMSeuZw+EElE9yUiYYolsAomU9w7ueLQlUjhW7RU44TzJdzCAMyMgXGXJuYtDncDFl8WoS5gz4+mn2xqqj3sWUqOQQCZmslpNjfven4V80VAFFOaomb6I+KZw0C4RMLxmC7vkdbhD65fnqqKiCjAmcsTF9Y21a3yQBbfMQCXxjNaDgIVwSy8E4/AiZG4+o5NlA4Zm6/td7YNbNVuHNbfb5ipVldE+GVsrKrWq349COyafK6gbjRsrFoMgohgRMQqslAb0DKmlLHFlXskNzrYF/364536490t8sCplGq/FUHljGrIvTr1TX1DYvvkRMZWR8Ombln4+n1OX5sjmy/h+x5BEBAEFoAgCNR1XfXCsfS1Am9uHFoR4MbrpHX4DVVEzo1OPhevqXlvJpstzc7Neb+eHmZudpb1a5rIZGcYOX+J6qoojQ11JJvvIBqN4DgO4XAItZbAlmloSHDxGk9s7K9fh78yTrz8lpwdnTxWW1Pblp5Ka8/nR53pTBbHcQjKFjGC77lYawkCSzgcwvc9fM8jFouRbF7PurWryqFQ2MzMZE5taGq8r3x804uOyjE3Gg4PTWWm2wZOD5HL5amKRlFVJLQQPFXFcRx8H6xV8vkCuVye9FSG8xcu8ugjreauLZskFIoUtBMjrYPvArifHvkyV7aYdHqyGFqcY4WQsxRTYxYy4boO1irf9Z4Izv52yY/43thTXdiTJ9/3tm59puSOj0/2hyOR0Xg83qRWK0D/RSLYIHD+uDqRn5ubHQE4evRKsGSCzoMHl5sgsgM1fmXHleU4DhiZNWUdfO3l3Rf/1uzs7DT/zWZl3cxZirT09PSYVCp12//5ZrW0tGgqldKuri77fxi8rf4Eb8vV3BImzFAAAAAASUVORK5CYII="
ICON_BIG_CLOUDY = "iVBORw0KGgoAAAANSUhEUgAAABYAAAAUCAYAAACJfM0wAAADm0lEQVR4nL1US29bRRT+zszch53cJM6javpIQytoBOwStWyKqFAWLIhUJAJ72LEACQQr5EqIBSriF3QBSCAUwy4RCCnYimpaRADxcKoQ24mDE7eOH4ntxI977xwWcUJSkEIB8e3OaM73nXPmmwP8n5iampLRaFSFw2HxH1EyMTMdFmHJzPJ+RdThkJgI+Hh67mJXZ3BIS3wzcYlW92WZRQSgSSL/KGJqJ1AsFpNVxzH9svv+wED/s0SEQqFU833v3b6e0C9WV+D7x0aGl9v35V4uAE1E+i/Zo9GoAoBPZuauJTJFzuQ33dR6wbv1c5IXsyXOluuczpUr6+WdL1O50tP35jPzn8akwmEWly+T99kXN8dN23hRwPeUsqTrenT8WB932paWgiEtw5GGMR4kMZ5eK75NkuqWZTeb281ZIvqBmYmI+OAo6NPp+JARNBaJyMqtZfnRh0fo5KkTCHWY6Ara+4XdKVX1dqMlunt6SAoJAGg06txoNN47O9j72vz8vDE6NuYRwAIA2532aH//gBm/Efc+/OAjWl7OwOkIwLFNMIB2GRRyAhJEVNna8svlklcul7x6vc4Dx0KvLq1tvDU2NuZ+Nz+vgLYrbi8kNhtNl5JLSTk5eQUXLoxiu7aNUKAbBEBrBgkCQGAGiCCJdt9Oa82lYsWzLfv1VK5069xg70w4HBYKAMVvzmV3ql78+eeeuTgx8ZSsVmtEUqHW9ODYBoQguJ6HfLkG01CQUsLzvHYvglotVyolheM406n1wrWzg31vEDMLItLMfDpbrC25rmtqrSmZWkEyvQJLSXQ5nVjL5dF0XYR6ujF85jTODJ0CEcE0DZimCe377Hqe7uvvlaVi+WUVAwTAnF4vPN7VE7IEwZ+NfS1//CkByzKhmaG1hlIKgghblSpWMll0dAQhBMG2LPT2hnD+oXN08sRxqtV2tNb8ktoAGCC2A5VV7fvenbsbIru2jmAwACklmBlEADMAMKTcdUOr1QIzY2enjnyhiF+X0hh/8hKNnH+Q7IDlqsTVqwwAn898lW/4Pt3Nb2jW2ichyNftn7vvzgMBEYgIAoChFHzWmI3G/duLaTPU3Znd2xWUWs1IqazfgsHgsBACzIfYjgTtSqqNQhGZzOomHTx/5/p1p7lFVyDpAbfZZNrz1N+AEAJCyQoB3775ygs3/mjwnnX5b3GIjJkpEomIRGKAgBiAJ+6TLoaFhUc4Epk8cq3+Y/wOwFW1epB3F4EAAAAASUVORK5CYII="
ICON_BIG_FOG = "iVBORw0KGgoAAAANSUhEUgAAABYAAAAUCAYAAACJfM0wAAACJElEQVR4nLWUP2hTURjFz3fffffFVOnfVNwslQ4JOFWchIKT6JoM6qBLQNFBSwcVfDywIEQFiwgZHOuQDrooSCl5gwVBHRyMQyxWKxFsNAptknffy/0ctGvNS+mZ7nC/c38czneBXRJtHVzXFZlMhra7/D8tAFjI5To7ptpO5Lqu8DzPXJt9cNxx1DkdhsTGiFgmEMZWSkRh8Gz2+qV513WFrFQqBABEmBscGU23NjchRCxfGGYopVD//i03XSg89WZmmjKdTnOpxNa71YdXGvX18zoMicCxsmYwK+UQCev5qcnJ4Es2G48sjqhcLst6y768J5k42mo2QUL01AxmZsdxSOvwo2zzbbnetscHBgfuJfv2Yl9/BKIeG8cAg2HbCrWvq69lKhGu1Bu/rgY6ONJuNomIesrnH7HROvgk22KpN7ouRABQLBbtiYkJXnpVOS2VOql1wITuMtlqRBjqt6OHx+4n1tZMPp+PJDMTEUXThUJSceLRUP+g1FpDdJk1gyGEhVAHufU3n5/cunmhWqvV/jagVCpZqVSKdkos9yfnMn19YW43/wsCMz1eXD6QFPYNYzrDURRR7JU2BpZlseM4zVardTd74th7CSJWL16eOTh+6GLj5w9YltUTYSfqYGhkGNUPFQXgrAQz6cXl+dWV6hgzD3Q6EZgRa0uIiIVFvLHxWzNwpyeyrh8DAGYm3/ctH8AUAD+mydbMFADf943neeYPqCT7vX1djHwAAAAASUVORK5CYII="
ICON_BIG_RAIN = "iVBORw0KGgoAAAANSUhEUgAAABYAAAAUCAYAAACJfM0wAAAD20lEQVR4nLVVPWxbVRg9333P79kmTmyncRpKVZUggRQQAQJFIlKaRkWQgSpDuqAKJDYkWJjRcwYYEAsUCTGAqPh3BzYQUhW3CCailiEq0CZx/hMnsZ3EiePn93wPg+00QSZi4Wz3fvee893v7wJNQFJIqma2VIpG3S7N7A2YzTZFhACYyRZ6rYA1IEoiIP+cmP7jh5f6pLQvQhqjAEVEHyUCkpJKpQySVmZ16/JSfpdbFTK3R+bL5GJu505mpXB2bm4zlifbDtxr+rqDxAYA3FlYv1whWSpXqp7vezt7rpdZyXsrm2VOL+f09EpuY359a3U5X/r+r0y290jyBmlmaf2RxfwuyxXfI6lZR7Hk8u7iRnVmJc/59W3OrW8zV9JcKeztTi/l+0nKxMREoMGnGiEAUItTwHo9FLRpCERrLSShtYZlKkCJIknP8+h7HguFvCeGCovClWQyKX19fV7D80Z2ZWFhwdZ26zehcPhCcXtbn+pqV+aBvO95GrliCdQanufv72utdTAUUkpkfGdr562HT3f+7jiOknQ6bQ4ODvrTq4UPOhPRNzfWN33fr5pzc4uIRYI43tGOqdkFzCxk0R6Poasrgc5EB0QAgYAAKq6rW1pbledViuWi+9yDJ2OTAgCTk9mWYNTIBMOh+Fp2DdfSv6iNXB4igoBpouL5EAFAwrZtPHCiC6ZpIhwOoqPjGE6dPAHTMNzWaNQu5Atfd98ff9kEgEjEDkhAzHDQVnenMlxb20Ak0gJqDU0iHLIBAhCB1hqZ2XmQBAGAQHt7DMMvnAtEY1EaSvUAgDiOowCg//kLP69mc2dmZmbp66pxVFmK3Au+AlCuVBCPtvmP9z6m4m2Rb59+9KFLjc6zrqV/jbW2RU2IwLLsmiv/ES2WhdKea928dRvbW/kEUG/pZDLpvvvhZ6PQ1TcgPOO5LihiCnl0qwpAQkRBm6ZZrPqV3yLB4Mc1y/8Nx3FUKpUygNrUGrpSeMJxqPbVSRlN0QAgqNf+wEfZlsHPiz0AMJpKGY7jmI2cHUZ9FPantjuGvitnB77YfbZ2ica9I5QBJ20CwLkvd14b+qo09dQnDNSd2MehxcB1GABgumo4GLcTpsLIQcL3brFXRJjoOVvLrMhIoDXUHYmUnhwbE33QgaYTSQSWsgBNsQHg6kWpvn8bz1gh/PTOTXZcvSjVulpQBQBWdeifHIeIbwyKDwDpu/d9urvsDrvl3bedxlCpYiR6HImgwosA4JAKfvkVN1c+f+NS5DpA2RfEv/wgGBM9DvwIAOe7aQLQBFqqPkhBpOHU+KvHlgAs1d95qPD/BsV7Bx59kdHRAAAAAElFTkSuQmCC"
ICON_BIG_SNOW = "iVBORw0KGgoAAAANSUhEUgAAABYAAAAUCAYAAACJfM0wAAADeklEQVR4nKVVPWwbZRh+3u/Od7YVJ7ZDHEJTVfwJBEVEKKhDKyAMCDFQCakTgqFMVIKFnfNQMbBBBzYQCyAzsDEVIiGYSEpBET9JHCdxUsd2fI7txLHvzt/DEF9qhLEq8Yzvz/O+3/v3AUNAUkiqYbpcjkZfL8P0IcxhQhEhABbK9TkrYj0vShIg/1zK//Htq/PSPg1CGlcAiogeFQQkJZfLGSStwl7jxq57xIZH1o5Jt0Pu1A5XC6X6C1tbBymXnBjwG/q6QWIDAFaL1RseyXbH6/lB4B8ed/1CyfVLBx3m79R0vlTb36429u647W/+KpTnRpKHpIXd6uM77hE7XuCT1Oyj1e5ybWe/t1FyuV1tcqvaZK2tWaofH+V33UskZWlpKRLyqbAEAE7qFLGuxaI2DYForYUktNawTAUoUSTp+z4D32e97vpiqLgofJ7NZmV+ft4PMw+7K8Vi0db2+JexePxyq9nU52YmlTnQ92Nfo9Zqg1rD94NTudZaR2MxpUS+P2wcvvfYg9O3HcdRsri4aC4sLAT5vfpH05nku/vVgyAIeubW1g5SiSjun5rE+mYRG8UyJtMpzMxkMJ2ZggggEBCA1+3qsfFx5fteq9PqXnzobGpFAGBlpTwWTRqFaDyWrpQruLn4o9qvuRARREwTnh9ABAAJ27Yxe2YGpmkiHo9iauo+nDt7BqZhdMeTSbvu1r94+IH06yYAJBJ2RCJixqO2WlsvsFLZRyIxBmoNTSIeswECEIHWGoXNbZAEAYDA5GQKr7z8YiSZStJQ6kkAEMdxFABceunyD3vl2oWNjU0GumeMGkuRu8VXADqeh3RyInh67imVnkh89ez5R94IN8+6ufhTanwiaUIElmWfpHKPGLMstI+71q1ffkez4WaA/kpns9nuBx9/egW69w6EF7xuRwQy8haEIEBRAtM0Wr3A+zkRjX4C4J58/x8cx1G5XM7A3dkehJzK+3M/xE4cxzHDnv0DoSHJJ0heJ/nc4Al1HA5uqpCcJfm+T75GUo26FyHx2ySPSH5IMkpSQtJBW5JvkaySzJGc7pP/u74DxLMkr5I8H+p+Xas889vmwWfL+crVkIDkBMk3SV7s+40+n8OC3cpXr61WPS6v176+vd7KjHw6/uMH6RMaOLl4AoCG4Lv24dF1Rb0892iiQlKJiA7t+r/OKf4GxkRCPdL0JXkAAAAASUVORK5CYII="
ICON_BIG_THUNDER = "iVBORw0KGgoAAAANSUhEUgAAABYAAAAUCAYAAACJfM0wAAAD8ElEQVR4nJ2UX2gcVRjFz3fvndnZJtnNJk1SkmKTIDYPKtJGJb4ksSIWESy4QQUR+iD4JCqKvrhvPuqzFARFI+xSWhACjeImSCIpSY0lKSRNo0lq4jZ/Npt1/2XuvZ8Pybb5T/F7GGaGM78599w5Axww8Xhcls/Hl5YqhocnasrXsVhMJJNJlUyy2qnbO7T3BjMLIrJX+0fayRGfGG3OAgh6gcDUpu9/8+q5Z77eoyciACA+FFyGXv5p6OWAE7xSX1/rSALWN7LY9A08z8N6evUSmO54AdfRzIOvdLX/uoPF+8DMLAYGBkTOhpp86080NTZUnqir8ZlZMRh/zv1t19YyVBUKCSG3ErDGoFgsJFRx5a1/z5/XUcASbTkXZfDY2Jjs7u7WvvGjkdqayupQhW+sdXytCSCqO14jSQiRz+dMdmNDZzcyOpfL6VB1JFpyIt/1EJlEAoKZ6T44FouJ9vZ2/+ov199zPffDbCZjrGVFRGBmCEHlVYGZJcCKiBTAan11VQeDx177MTnybk8PmW3HRPF4XPb09Jgr/UOf19Y1fLqeXgMA1NZU42RjPVw3gGw2i5nZeWhj4TgOfN8HM2/HYQEBU1kZkoV8LlFc0W9PTnaUCADi1wZbPCc4w8wMMC3M3xXTU9MgAurrj2Nu7i7y+TzC1WE0NTWhpbUFUkoopRAIBAAAm6WSX9dwwlleXv7ywgvPfkAAcPnab69Xhap+sEabG2M35PDQMFzXBTNDawPHUZBCQBsDtozgsSCklHBdF+HqMFpbW3Gq+ZRVSnGxWFwWefuYAoDKKm+BwTqVSonpqWl4ngelFJgZgQCVs4UrJYgArTV830ehUEA6ncbM7Rl0PNdBZ86eEZ7nbTpkhQKAvr7+FbPpUyqVsmzZCCnIGLPrw+TtozYkCGSF2Np7pRQcx8HY6KiZn1twIpHw6vDP6ZwCQHNzfwkFueAFg80kxP2N2dUkAowhhNw8HEeJTM6FFAx+UAaVyWSw9M/iatVpdqncmIsXP6oqCH2BQC3G+My8VdStyhILYUW+6Np3Xpzo7h9/ZHBhtYIdWXYgQIKKUuH69199MUhE9sBqHza8HnmJZ5s/fhit2hEhdXbGJLp2C95sXKLIYpqeOnc7rGdLl/KlwPMAobPzM7VXW3/rFicSCYsd/4zDXcajEgD499O9fLNthPseDfGdxxt4/mTwqOeOjIA5KokShv9oewNNTi8W/Sxc8qH5HqzqwhMT9wCAaL9DsR+3cxKW45BgfhoZ3QvLeVSIGmj7Pj05kUIiKg6CPtQwb72cR1vDPN1W4vG2WHk1/wv4AByVzBB8s+1bnmwbBwBOdirmo2P8D1F171c6gGWOAAAAAElFTkSuQmCC"
ICON_SMALL_SUN = "iVBORw0KGgoAAAANSUhEUgAAAA4AAAANCAYAAACZ3F9/AAAB+UlEQVR4nF2SP2hTYRTFf9+Xl6S0aZcSEVqNtMl7SYxd6lSRIo6Cm4uTgpuiq7RDtuLi0E4Ogk4OcXMVecX8AcGCQ0kh8V+VgradbCRtzPuOQ1q0veM953LuvecAoDAzpFowCqD1YgJANf+JqsGD471gVGFmCMBKGJIjw8gsa7WQM6VmTxViyK4j80kVYqbU7Gm1kENmmeTIsIRBZexA1c+rmn+pMDsJoHczvj7M+AMsOznA/DyAylijcN4jvWNNqdlTIzeBsyls9AhjrwOAfUWkh1jXMXPtLa0XE+ykneFE6e30M85N3mJ/2rH3FVI/LNt6bi5v3P6fZ1QPHjMUs/x230mMPeVg9xunZ1OMnTfsfYHdhohiHeL9s/S8O4zYM+xHzsPRQrJYbdPtODyvz68W7HdE9ydYC5H6dBOOeLSJ1MXhTm6KasGS2iWpNi01fKl9QaoFSyd5RroRY+2zNRfX/qiRm8DKEHn38exNJIj0glh/BWdk5tpbej8bZ3bK/bOjFgSqBhXVC5mBHflx1adOAehNIaNqUFEtCI7sGAy9zo8DC3h20Vza2FQ479GLrqH4PYXznrm6sYlnF4GFQ+7hXa1sUmExBaDKYbyq/l3V8yvHIhcWU2plkwAegPE/HgAHKmNJpwcfMybCqQ/ATtqpjDVXmp0jsb/whvzNrRShRgAAAABJRU5ErkJggg=="
ICON_SMALL_PARTLY_CLOUDY = "iVBORw0KGgoAAAANSUhEUgAAAA4AAAANCAYAAACZ3F9/AAACD0lEQVR4nJ2RzUtUYRTGn/fc9873hx+jGUpRC4syNIaMjD6pdkEG4h8grmvZTiRoacuoTQsXwUSrNgWhUhqVQ0E5puNQDuNMJo7jDDM6c+9939NiEpxV0G97zu+cBx6BffAYCNeP+aHxAOBP4mJykp9e8uB4vlucW/jKsyf6wOo5gDHRIPK0BC6rzbmRQETM96Nc3EbIfQ9StMESL6FoFlI0i4HFV/skbjzyGD6ej5Z4Y5Q5dZt55STzbPf9vbkAICAEgxnpzNJdw9dxfscOr3alB5u9/tQIQlcs2DXC1nugauXh0DWYPCLj8biMRqMqld2aONTZcgcAijZQoocoFT6yqdgVyj/SUuwSyGPD45ShOAkA+Lyc6S3bzMxsMbO9U63Zyey2Wlmv8fIvxWvpuMNfenZ5un10Lyol1zZOt7aGJ5VSCoABQIIM6XUT+cwqfLLE1NRHa5EX6UrwpsUzHUMAIH6uF1YDgeDhd3MftFOrUtDvRSqdRVNTGB0H2uF2uxBpCeu2g51ULGwmj/y4OkOiMi1yWxXn28J39XrqLUlDQjNDGgaYdT0SEdwuExcGznDPqV5druT6jybO1sTEk2eW0jBt2waR+FsNGnAcB6ZporU5iLZIV+etG9GczGRyw4Ggf5CE8NS/UKMFDSJirbVeXPo95RTe5GOxIQP/i4jFYkYikRD/Xq0zPj7uAMAfyE73Zw224PAAAAAASUVORK5CYII="
ICON_SMALL_CLOUDY = "iVBORw0KGgoAAAANSUhEUgAAAA4AAAANCAYAAACZ3F9/AAAB60lEQVR4nJ2Sv2tTYRSG3/N93429aWNuG3tLk7SEOkWqQh0EQegk9J9w0qGTqy7egCC6FRxbipty3UQHUTCDaKFKg4RKTNU2pdokTU1ie5PeX6dDFauIQx8403uGB96X8BNmpnw+LwEgPzkZ5gAmIsZRYGbJzPSvTFmWJXK5HO4/emqaw6mbnuvyrtOZ2ZJOhYj2ftkAEDiwCAEAlsUCAJ69LrxoeszLa3UufFx3vmy2ypXGzszKtx/mXxYEAGTbtoyaY/cMIz5tJuJurFcXJ+J9KmSgEwLbje8VpeSWpkWKze3G7exYusTMUuiDmazretNzs/NcXvkcGTJ6leCAIxJh0HV8IdSolGpCj/ZcjsZiL4vFah8RBWrh3WKr9P7D6tTUpczZM+Pc9UPSNUkAqOv6QggKOQzRbrWDqB4dxiA/XK3VrhIAvHq7fGXiXHZ2qVAKCoWiPJlJotnawae1DYyOpJBKDkEphcSAEabTSVGrN8oEANV294amyVtz8w+Car2hhBAgImhKwg8CAAARQe85hosXzgenx7OaAoDHT55/ZZKy03XlQH8/QAAYYGYQ/a7R8z28WVwS6xubIGama9fvjhxPGHc0JU/5ns90+PsQRAIM3nN2OwtHWtQfpdq2LXEg+d9jZrIsS+0DcFbcsnm+e30AAAAASUVORK5CYII="
ICON_SMALL_FOG = "iVBORw0KGgoAAAANSUhEUgAAAA4AAAANCAYAAACZ3F9/AAABbElEQVR4nJ1Sv2tTYRQ958t9Sb6YxIKbLpVOLqVQR/8D/wP/gEILiqCWQisZnNpBOjm4dO3m4h6XDCJY6JQ6thSHNAm19f363rvXoUXQ2kfxwN3O4Z57zgUA9Ho9B4A3mUvu/4Nmxo3Nd68aTf8si5MStNq/iGbQhvcupOnHN2sry0LSnq5v7c84+ZSFXAFcZ0WdiPt5Hn8hafzQ35tp1HSRdKWIVNorigK1er02np58k5CeLd2dndvM8xwkK4WqCu9b+DGZ7ErU7Lz/fnQ4bHfbZ0VRVArNYNPJ+Hagfv294mXv7WrDNx9kWaq0P+800kSEquVo6/XzVeCyl/P2nK/np4Moqs+HIpSwK8maEwFUTxDhobxYOeaFBeNgMGwPDw86SRwDaP2li+FbLfjuneTJ40enJJU7/X6zk0WfvffzSZKUuL4OkyhyIQ9TE1uQW6NRYPfethH3VRW8eK0roHMGEjBMU+2MK1Oswi9qNpsIh2hfJAAAAABJRU5ErkJggg=="
ICON_SMALL_RAIN = "iVBORw0KGgoAAAANSUhEUgAAAA4AAAANCAYAAACZ3F9/AAACK0lEQVR4nG2RP2hTYRTFz/e9l/fapklbQ6KDg1BQ0KUinaRVUKmDuLWrmyDo4CB0q0GcVKSjShE3objUQRz0Da6CiK3B15jXmKZN06Rp074k7993HNpClP6mey/nXg7nAgeQFIe102gM2rZtoguSslsjDocA+LtSSfca/U81TbsSRNzz/M6cIYwPgVTecGbAxn+XBElpWdQL61vfeIAXkZWmz2J1h6tbe4FT2X7jOE6PZVk6SQGSGgDYpdr9XX9/h6QiGRWr22F+rc58uRa1SC6X648AwCJ1AIBd3pze8clidcdvNF0qRf5Zq/LnSoWlzSZLtV211nD9jaYX2aWNaQAQudxmIpHpzQdhmF54/xG7e65IJvpQq2/DNAyk0ynEYjEMDiRx5vQwMpk0arX6mO55ofJq9Xa+UFSr5XVlmoZ0XRe6rqPdbqPgFAEAYRji13JB3bwxETMN7YS4NztrJlral/54chQCEEICVOBh7GI/fCElwiBAGPhhj2FcFAAw8/z1oKmL8bDj6jJqeb5M9imlhBRCQAgllKKpmi3Gj/f7fnsx++BO7p/XYJHGyDuO4gjOv+V4dy8A4PaLr7GrQwX10pu4q6T2OGWvHDt7OS6DKJEa2fpcedW5dgm98U+RWzk55sytZwFIAGgMXVBTU1NRJI2mEDI/nz0XJFKnrg+lU/NLS5OEND0AuY6RYjabVUc5wi3L6QGAJ9/58NkPRjML7AOAyZlFo1v3F6ToQBRsukMcAAAAAElFTkSuQmCC"
ICON_SMALL_SNOW = "iVBORw0KGgoAAAANSUhEUgAAAA4AAAANCAYAAACZ3F9/AAACEklEQVR4nG1SPW/TUBQ97/nFTkuTpkKJECOVQAxsMCFYGBhAbAysbAwMDKBuEWJFQv0BgGBB6ggDYvLAwIJUJkLdNCGkadPEado4bmL7+R2GOBIgznKvru6XzjlABpJinjeHw5LneQ7+AEn5Z4+YFwFwp9stL9hLzy3LupGkHEfx9KUt7I+JNNFqZdnDP5sESem6VI39w01miFKyO4rZ6h1z93CcNLtHb5rNZt51XUVSgKQFAF7bfxTEsxmShmTa6h3p+t6A9Y6fnpDc7gyeAYBLKgCA1+mvHcdkq3ccD0chjSF/7fX4/WeX7f6IbT8we8MwPhhFqdc+WAMAUav1C4XKQj3Ruvz+wycE41AUC4vwB0dwbBvl8mnkcjmUlou4cH4VlUoZvj+4pqJIm8gfTOqNltnt7BvHsWUYhlBKYTKZoNFsAQC01tjabpg7t2/mHNs6Ix6urzuFE+vz0qniFSEFxIwwcE67mJEvpYTWGkkc6bxtXxUAUH3xuuQocX08nljT6TRdXMjnpZQUwghSEgBGQThdKRVtY5La08cPan9Jk887ILmE/4BkSYr5F1niuq7a2NiwkiR5q7Xe7/f7Z2fmuGsBQBBEl7TWJ7HWT6rVquRcjsw5IHlZa32PpNzc6d360Q2+fdnyL5LMaa3vkzw3N43MTpssflVKvRNCmIQwqU5XpDKpECJRSr0SQjSyPv4G0qRV0IuLfNwAAAAASUVORK5CYII="
ICON_SMALL_THUNDER = "iVBORw0KGgoAAAANSUhEUgAAAA4AAAANCAYAAACZ3F9/AAACPUlEQVR4nG2SzUtUYRjFz/Pe947zcWfujFqoYwtRc5KoP6CFDkggQdBCLVxELapdUO5vLmrRJnLVl0srTI3ERSExSp9CoglJIdJM1ITddHRmFOfeufdpMWom/ZbnPIezOA+whWEYAgCu3+7fN/T8Xdfo5IfjzEzYxfYNABAADDIrXUI4D8cS7dHqmvtBzR81lzPI53ITipTjUpXrq5m1ge6T8d8Gs+glcqVhGKKTyLlg3PVX6OHH9XUHQkW74Ahi4RSdVtXjaVUUBWD0PBp52XqGaDGRSEgJAONTUxX5LN/TQlpIEDuKIpVIWMePn6abz2ZdBjtaMFgbLNfvjIyMn47H48vEzDT84u1wTTR6anFhoejzqrK6aj+mZ+YACERro/B4PCAiJ6AFlUxmZbZY2GyngbFXkcpyfcE0zfDo02eiUCiQlBKWZUNKBeGwjrIyL0J6CI2NDfbhI0dV89fSNaluKJuzyZmNZDJVUSzars/ng+u6CAQkuUxYXc2zoCzS6TRSyZTI5tbh93qJWlpapF7V9MDn958lApgBIsBlgios1jUmc80LVTIcx4Vt2ctFx7q0s1P3xavNtuWqgA1VZeW76bX6zr8/93VJm7w/0ZzSvQUC/PAFA9/6b/Wu/LPnbpj1Ov5cf3OvvuXSTsAwDDE/P09tbRFxLPK6LHbQfUMaSTfH0+l85eWevuosOoAnnYMuQLynpdTMHxtq+VPTDf5yiHkudqXkdSj/b98Jlw54LnaCZ2JDJe3vj27zB1Vd95qgChRVAAAAAElFTkSuQmCC"

DEFAULT_LOCATION = """
{
    "lat": "40.6781784",
    "lng": "-73.9441579",
    "description": "Brooklyn, NY",
    "locality": "Brooklyn",
    "place_id": "",
    "timezone": "America/New_York"
}
"""

CACHE_TTL_SECONDS = 1800

WIDTH = 64
HEIGHT = 32

HOLD_FRAMES = 40
SLIDE_FRAMES = 10
FRAME_DELAY_MS = 90

BG_COLOR = "#000"
TEXT_COLOR = "#fff"
DIM_COLOR = "#999"
HIGH_COLOR = "#f77"
LOW_COLOR = "#7af"
DIVIDER_COLOR = "#333"

BIG_ICON_W = 22
BIG_ICON_H = 20
SMALL_ICON_W = 14
SMALL_ICON_H = 13

def main(config):
    location = config.str("location", DEFAULT_LOCATION)
    loc = json.decode(location)
    units = config.str("units", "fahrenheit")

    data = get_forecast(loc["lat"], loc["lng"], units)
    if data == None:
        return error_root("Weather data unavailable")

    days = build_days(data, units)
    if len(days) == 0:
        return error_root("No forecast data")

    today_card = build_today_card(days[0])
    thirds_card = build_thirds_card(days)

    frames = []
    for _ in range(HOLD_FRAMES):
        frames.append(today_card)
    for f in range(1, SLIDE_FRAMES + 1):
        offset = int(WIDTH * f / SLIDE_FRAMES)
        frames.append(slide_frame(today_card, thirds_card, offset))

    for _ in range(HOLD_FRAMES):
        frames.append(thirds_card)
    for f in range(1, SLIDE_FRAMES + 1):
        offset = int(WIDTH * f / SLIDE_FRAMES)
        frames.append(slide_frame(thirds_card, today_card, offset))

    return render.Root(
        delay = FRAME_DELAY_MS,
        child = render.Animation(children = frames),
    )

def slide_frame(current, upcoming, offset):
    return render.Stack(
        children = [
            render.Padding(pad = (-offset, 0, 0, 0), child = current),
            render.Padding(pad = (WIDTH - offset, 0, 0, 0), child = upcoming),
        ],
    )

def build_days(data, units):
    daily = data.get("daily", {})
    times = daily.get("time", [])
    codes = daily.get("weather_code", [])
    highs = daily.get("temperature_2m_max", [])
    lows = daily.get("temperature_2m_min", [])

    current = data.get("current", {})
    current_temp = current.get("temperature_2m", None)
    current_code = current.get("weather_code", None)

    unit_suffix = "F" if units == "fahrenheit" else "C"

    days = []
    for i in range(min(3, len(times))):
        days.append({
            "label": day_label(i, times[i]),
            "short_label": day_label_short(i, times[i]),
            "code": codes[i] if i < len(codes) else 0,
            "high": int(math.round(highs[i])) if i < len(highs) else None,
            "low": int(math.round(lows[i])) if i < len(lows) else None,
            "current": int(math.round(current_temp)) if i == 0 and current_temp != None else None,
            "current_code": current_code if i == 0 else None,
            "unit": unit_suffix,
        })

    return days

def day_label(i, date_str):
    if i == 0:
        return "TODAY"
    if i == 1:
        return "TOMORROW"

    t = time.parse_time(date_str, format = "2006-01-02")
    return t.format("Mon").upper()

def day_label_short(i, date_str):
    if i == 0:
        return "TODAY"
    if i == 1:
        return "TMRW"

    t = time.parse_time(date_str, format = "2006-01-02")
    return t.format("Mon").upper()

def build_today_card(day):
    icon_code = day["current_code"] if day["current_code"] != None else day["code"]
    icon = weather_icon(icon_code, "big")

    header_children = [
        render.Text(day["label"], font = "tom-thumb", color = DIM_COLOR),
    ]
    if day["current"] != None:
        header_children.append(render.Text(
            "%d°%s" % (day["current"], day["unit"]),
            font = "tom-thumb",
            color = TEXT_COLOR,
        ))

    hi_lo = build_hi_lo_row(day)

    return render.Stack(
        children = [
            render.Box(width = WIDTH, height = HEIGHT, color = BG_COLOR),
            render.Padding(
                pad = (2, 1, 2, 1),
                child = render.Column(
                    expanded = True,
                    main_align = "space_between",
                    children = [
                        render.Row(
                            expanded = True,
                            main_align = "space_between",
                            children = header_children,
                        ),
                        render.Box(height = 1),
                        hi_lo,
                    ],
                ),
            ),
            render.Padding(
                pad = (WIDTH - BIG_ICON_W - 2, 7, 0, 0),
                child = icon,
            ),
        ],
    )

def build_hi_lo_row(day):
    if day["high"] == None or day["low"] == None:
        return render.Text("")

    return render.Row(
        expanded = True,
        main_align = "center",
        cross_align = "center",
        children = [
            render.Text("H:", font = "tom-thumb", color = DIM_COLOR),
            render.Text("%d°" % day["high"], font = "tom-thumb", color = HIGH_COLOR),
            render.Box(width = 4, height = 1),
            render.Text("L:", font = "tom-thumb", color = DIM_COLOR),
            render.Text("%d°" % day["low"], font = "tom-thumb", color = LOW_COLOR),
        ],
    )

def build_thirds_card(days):
    col_widths = [20, 21, 21]
    columns = []
    for i, day in enumerate(days):
        columns.append(build_day_column(day, col_widths[i]))
        if i < len(days) - 1:
            columns.append(render.Box(width = 1, height = HEIGHT, color = DIVIDER_COLOR))

    return render.Stack(
        children = [
            render.Box(width = WIDTH, height = HEIGHT, color = BG_COLOR),
            render.Row(children = columns),
        ],
    )

def build_day_column(day, width):
    icon_code = day["current_code"] if day["current_code"] != None else day["code"]
    icon = weather_icon(icon_code, "small")

    hi_lo = render.Column(
        cross_align = "center",
        children = [
            render.Text("%d°" % day["high"], font = "tom-thumb", color = HIGH_COLOR) if day["high"] != None else render.Text(""),
            render.Text("%d°" % day["low"], font = "tom-thumb", color = LOW_COLOR) if day["low"] != None else render.Text(""),
        ],
    )

    return render.Box(
        width = width,
        height = HEIGHT,
        child = render.Padding(
            pad = (0, 1, 0, 1),
            child = render.Column(
                expanded = True,
                main_align = "space_between",
                cross_align = "center",
                children = [
                    render.Text(day["short_label"], font = "tom-thumb", color = DIM_COLOR),
                    icon,
                    hi_lo,
                ],
            ),
        ),
    )

def error_root(msg):
    return render.Root(
        child = render.Box(
            child = render.WrappedText(
                content = msg,
                font = "tom-thumb",
                align = "center",
            ),
        ),
    )

def get_forecast(lat, lng, units):
    res = http.get(
        "https://api.open-meteo.com/v1/forecast",
        params = {
            "latitude": lat,
            "longitude": lng,
            "current": "temperature_2m,weather_code",
            "daily": "weather_code,temperature_2m_max,temperature_2m_min",
            "temperature_unit": units,
            "timezone": "auto",
            "forecast_days": "3",
        },
        ttl_seconds = CACHE_TTL_SECONDS,
    )
    if res.status_code != 200:
        return None

    return res.json()

# --- Pixel-art weather icons ---
#
# Each icon is a small pre-rendered PNG (embedded below as base64) keyed
# off the WMO weather code groups documented at
# https://open-meteo.com/en/docs#weathervariables. Two sizes are baked in:
# "big" for the full-screen today card and "small" for the 3-up columns.

def weather_icon(code, size):
    category = weather_category(code)
    icons = ICONS_BIG if size == "big" else ICONS_SMALL
    w, h = (BIG_ICON_W, BIG_ICON_H) if size == "big" else (SMALL_ICON_W, SMALL_ICON_H)
    return render.Image(src = base64.decode(icons[category]), width = w, height = h)

def weather_category(code):
    if code == 0 or code == 1:
        return "sun"
    if code == 2:
        return "partly_cloudy"
    if code == 3:
        return "cloudy"
    if code == 45 or code == 48:
        return "fog"
    if code in (51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82):
        return "rain"
    if code in (71, 73, 75, 77, 85, 86):
        return "snow"
    if code in (95, 96, 99):
        return "thunder"
    return "cloudy"

ICONS_BIG = {
    "sun": ICON_BIG_SUN,
    "partly_cloudy": ICON_BIG_PARTLY_CLOUDY,
    "cloudy": ICON_BIG_CLOUDY,
    "fog": ICON_BIG_FOG,
    "rain": ICON_BIG_RAIN,
    "snow": ICON_BIG_SNOW,
    "thunder": ICON_BIG_THUNDER,
}

ICONS_SMALL = {
    "sun": ICON_SMALL_SUN,
    "partly_cloudy": ICON_SMALL_PARTLY_CLOUDY,
    "cloudy": ICON_SMALL_CLOUDY,
    "fog": ICON_SMALL_FOG,
    "rain": ICON_SMALL_RAIN,
    "snow": ICON_SMALL_SNOW,
    "thunder": ICON_SMALL_THUNDER,
}

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Location(
                id = "location",
                name = "Location",
                desc = "Where to fetch the weather forecast for.",
                icon = "locationDot",
            ),
            schema.Dropdown(
                id = "units",
                name = "Temperature Units",
                desc = "Fahrenheit or Celsius.",
                icon = "temperatureHalf",
                default = "fahrenheit",
                options = [
                    schema.Option(display = "Fahrenheit (°F)", value = "fahrenheit"),
                    schema.Option(display = "Celsius (°C)", value = "celsius"),
                ],
            ),
        ],
    )
